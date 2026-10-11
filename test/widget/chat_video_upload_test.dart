import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_file_body.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_video_tile.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_video_tile_parts.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

// A 1×1 transparent PNG, standing in for the video's preview frame.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  const video = FileContent(
    fileId: 0,
    name: 'clip.mp4',
    size: 5000000,
    time: 0,
  );

  Future<void> pump(WidgetTester tester, SendState state) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatPendingVideoThumbnailProvider((
            gid: 'g1',
            name: 'clip.mp4',
          )).overrideWith((ref) async => Ok(_png)),
          chatUploadProgressProvider(
            'g1',
          ).overrideWith((ref) => Stream.value(0.4)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: FileBody(
                accountId: 'zt',
                message: ChatMessage(
                  accountId: 'zt',
                  gid: 'g1',
                  chatGid: 'c1',
                  senderId: 1,
                  sentAt: DateTime(2026, 10, 10),
                  content: video,
                  isMine: true,
                  sendState: state,
                ),
                file: video,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a sending video is drawn as a video with the % sent', (
    tester,
  ) async {
    await pump(tester, SendState.pending);
    expect(find.byType(ChatVideoTile), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    // Name and size sit inside the 16:9 frame, not under it.
    for (final label in ['clip.mp4', '4.8 MB']) {
      expect(
        find.descendant(
          of: find.byType(AspectRatio),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('a failed video upload stays a video, without progress', (
    tester,
  ) async {
    await pump(tester, SendState.failed);
    expect(find.byType(ChatVideoTile), findsOneWidget);
  });

  testWidgets('hovering a sending video\'s progress shows a ✕', (tester) async {
    await pump(tester, SendState.pending);
    expect(find.byIcon(LucideIcons.x300), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(ChatVideoCancelDisc)));
    await tester.pump();

    expect(find.byIcon(LucideIcons.x300), findsOneWidget);
    expect(find.text('40%'), findsNothing);
  });
}

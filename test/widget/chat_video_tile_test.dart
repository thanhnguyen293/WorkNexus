import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_video_tile.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

// A 1×1 transparent PNG, standing in for the video's preview frame.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  const video = FileContent(
    fileId: 7,
    name: 'clip.mp4',
    size: 5000000,
    time: 0,
  );

  testWidgets('time sits bottom-left, full screen bottom-right', (
    tester,
  ) async {
    var fullScreens = 0;
    final key = (accountId: 'zt', content: video as MessageContent);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatVideoThumbnailProvider((
            accountId: 'zt',
            video: video,
          )).overrideWith((ref) async => Ok(_png)),
          chatVideoDurationProvider((
            accountId: 'zt',
            video: video,
          )).overrideWith((ref) async => const Ok(Duration(seconds: 10))),
          chatAttachmentCachedProvider(key).overrideWith((ref) async => true),
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
            body: Center(
              child: SizedBox(
                width: 400,
                child: ChatVideoTile(
                  accountId: 'zt',
                  file: video,
                  onFullScreen: () => fullScreens++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final frame = tester.getRect(find.byType(ChatVideoTile));
    final time = tester.getRect(find.text('0:10'));
    final full = tester.getRect(find.byIcon(PhosphorIconsLight.cornersOut));
    expect(time.center.dx, lessThan(frame.center.dx));
    expect(time.center.dy, greaterThan(frame.center.dy));
    expect(full.center.dx, greaterThan(frame.center.dx));
    expect(full.center.dy, greaterThan(frame.center.dy));
    expect(find.byIcon(PhosphorIconsFill.play), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIconsLight.cornersOut));
    expect(fullScreens, 1);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_image_body.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_upload_overlay.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

// A 1×1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  const image = ImageContent(
    fileId: 0,
    name: 'shot.png',
    size: 68,
    time: 0,
    width: 320,
    height: 200,
  );

  ChatMessage message(SendState state) => ChatMessage(
    accountId: 'zt',
    gid: 'g1',
    chatGid: 'c1',
    senderId: 1,
    sentAt: DateTime(2026, 10, 10),
    content: image,
    isMine: true,
    sendState: state,
  );

  Future<void> pump(WidgetTester tester, SendState state) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatPendingUploadBytesProvider('g1').overrideWithValue(_png),
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
            body: ChatImageBody(
              accountId: 'zt',
              message: message(state),
              image: image,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a sending image shows the picked bytes and the % sent', (
    tester,
  ) async {
    await pump(tester, SendState.pending);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('a failed upload keeps the picture, without progress', (
    tester,
  ) async {
    await pump(tester, SendState.failed);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ChatUploadOverlay), findsNothing);
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/rich_body_text.dart';

void main() {
  testWidgets(
    'an HTML description can be selected and copied',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(
            body: SelectionArea(
              child: RichBodyText('<p>Uploading - Transcoding</p>', html: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = find.textContaining('Uploading', findRichText: true);
      final box = tester.getRect(text);
      final mouse = await tester.startGesture(
        box.centerLeft + const Offset(1, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await mouse.moveTo(box.centerRight - const Offset(1, 0));
      await mouse.up();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

      expect(copied, contains('Transcoding'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

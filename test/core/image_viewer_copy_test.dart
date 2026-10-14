import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/image_viewer_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// A 1×1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// `pasteboard` sends an image over its channel on macOS only: on Windows it
/// writes a temp file and sends its path, and on Linux it does nothing. These
/// tests read the channel, so they run where it is used.
final _skipChannelCopy = !Platform.isMacOS;

void main() {
  late List<MethodCall> calls;

  Future<void> pump(WidgetTester tester) async {
    calls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: ImageViewerDialog(bytes: _png)),
      ),
    );
    // The bytes are decoded off the fake clock; until then the image has no
    // size to click.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the copy button puts the image on the clipboard',
    skip: _skipChannelCopy,
    (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(LucideIcons.copy300));
      await tester.pump();

      expect(calls.single.method, 'writeImage');
      expect(calls.single.arguments, _png);
      // A check confirms the copy for a moment, then the button comes back.
      expect(find.byIcon(LucideIcons.check300), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(LucideIcons.copy300), findsOneWidget);
    },
  );

  testWidgets(
    'a right-click on the image copies it from its menu',
    skip: _skipChannelCopy,
    (tester) async {
      await pump(tester);

      await tester.tap(find.byType(Image), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy image'));
      await tester.pumpAndSettle();

      expect(calls.single.method, 'writeImage');
      // The bar confirms it, as for its own button.
      expect(find.byIcon(LucideIcons.check300), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    },
  );
}

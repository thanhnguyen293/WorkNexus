import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/image_viewer_dialog.dart';
import 'package:work_nexus/core/widgets/inline_image.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// A 1×1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  Future<void> pump(WidgetTester tester, {bool zoomable = true}) async {
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
        home: Scaffold(
          body: InlineImage(
            url: 'https://zentao.example.com/file-1.png',
            loader: (_) async => _png,
            width: 200,
            zoomable: zoomable,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The bytes are decoded off the fake clock; until then the image has no
    // height to click.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('clicking an image opens it enlarged; close closes it', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byType(InlineImage));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerDialog), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerDialog), findsNothing);
  });

  testWidgets('an image being edited does not open the viewer', (tester) async {
    await pump(tester, zoomable: false);

    await tester.tap(find.byType(InlineImage));
    await tester.pumpAndSettle();

    expect(find.byType(ImageViewerDialog), findsNothing);
  });
}

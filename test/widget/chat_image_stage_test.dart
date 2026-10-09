import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_image_stage.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// A 1×1 PNG: the tiny preview of a much larger original.
final _preview = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  Future<void> pumpStage(
    WidgetTester tester, {
    Size? originalSize,
    bool loading = false,
    double? progress,
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: ChatImageStage(
            transform: TransformationController(),
            bytes: _preview,
            originalSize: originalSize,
            turns: 0,
            minScale: 0.25,
            maxScale: 8,
            roomForArrows: false,
            loading: loading,
            progress: progress,
            totalBytes: 400 * 1024,
            failed: false,
            onDoubleTap: () {},
            onPrevious: null,
            onNext: null,
          ),
        ),
      ),
    );
  }

  testWidgets('the preview takes the original\'s size, not its own', (
    tester,
  ) async {
    await pumpStage(tester, originalSize: const Size(818, 724));

    expect(tester.getRect(find.byType(Image)).size, const Size(818, 724));
  });

  testWidgets('a larger original is shrunk to fit, keeping its shape', (
    tester,
  ) async {
    await pumpStage(tester, originalSize: const Size(4000, 2000));

    // On screen, after the FittedBox scales it down.
    final size = tester.getRect(find.byType(Image)).size;
    expect(size.width, lessThan(1400));
    expect(size.width / size.height, closeTo(2, 0.01));
  });

  testWidgets('loading shows how much of the original has arrived', (
    tester,
  ) async {
    await pumpStage(tester, loading: true, progress: 0.5);

    expect(find.text('200 KB / 400 KB'), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 0.5);
  });
}

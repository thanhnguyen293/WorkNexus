import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_avatar_crop.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_avatar_crop_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  ChatAvatarCrop? result;

  Future<void> open(WidgetTester tester, Uint8List image) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await ChatAvatarCropDialog.show(context, image),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    // Decoding the picture is real async work.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  /// [result] in picture px, rounded off the view's float maths.
  List<double> cropOf(ChatAvatarCrop? crop) => [
    for (final v in [crop!.left, crop.top, crop.side])
      (v * 100).roundToDouble() / 100,
  ];

  /// The shown picture's rect: the frame starts on its centred square.
  Rect picture(WidgetTester tester) => tester.getRect(find.byType(Image));

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.text('Use this picture'));
    await tester.pumpAndSettle();
  }

  testWidgets('keeps the centred square unless changed', (tester) async {
    final image = (await tester.runAsync(() => _png(200, 100)))!;
    await open(tester, image);

    await apply(tester);

    expect(cropOf(result), [50, 0, 100]);
  });

  testWidgets('dragging a corner resizes the frame about the other one', (
    tester,
  ) async {
    final image = (await tester.runAsync(() => _png(200, 100)))!;
    await open(tester, image);
    final shown = picture(tester);
    // The frame's bottom-right corner; half its side in view px back.
    final corner = Offset(shown.center.dx + shown.height / 2, shown.bottom);

    await tester.dragFrom(corner, Offset(-shown.height / 2, 0));
    await tester.pumpAndSettle();
    await apply(tester);

    expect(cropOf(result), [50, 0, 50]);
  });

  testWidgets('dragging the frame moves it, kept on the picture', (
    tester,
  ) async {
    final image = (await tester.runAsync(() => _png(200, 100)))!;
    await open(tester, image);
    final shown = picture(tester);

    await tester.dragFrom(shown.center, Offset(shown.width, shown.height));
    await tester.pumpAndSettle();
    await apply(tester);

    expect(cropOf(result), [100, 0, 100]);
  });

  testWidgets('a picture that does not open cannot be used', (tester) async {
    await open(tester, Uint8List.fromList([1, 2, 3]));

    expect(find.text("This picture can't be opened"), findsOneWidget);
    await tester.tap(find.text('Use this picture'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatAvatarCropDialog), findsOneWidget);
    expect(result, isNull);
  });
}

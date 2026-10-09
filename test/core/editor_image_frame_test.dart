import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/editor_image_frame.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<List<double?>> pump(WidgetTester tester, {double? width}) async {
    final resized = <double?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: EditorImageFrame(
              width: width,
              onResize: resized.add,
              builder: (w) =>
                  SizedBox(key: const Key('img'), width: w ?? 300, height: 200),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('img'))));
    await tester.pump();
    return resized;
  }

  /// The edge handle sits on the image's right edge, halfway down.
  Offset edgeHandle(WidgetTester tester) {
    final rect = tester.getRect(find.byKey(const Key('img')));
    return Offset(rect.right - 6, rect.center.dy);
  }

  testWidgets('dragging the edge resizes live and stores the width', (
    tester,
  ) async {
    final resized = await pump(tester);

    final drag = await tester.startGesture(edgeHandle(tester));
    await drag.moveBy(const Offset(40, 0));
    await drag.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('img'))).width, 400);
    expect(find.text('400 px'), findsOneWidget);

    await drag.up();
    await tester.pump();
    expect(resized, [400]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the width never passes the editor or gets too small', (
    tester,
  ) async {
    final resized = await pump(tester);

    final drag = await tester.startGesture(edgeHandle(tester));
    await drag.moveBy(const Offset(-500, 0));
    await drag.up();
    await tester.pump();
    final wide = await tester.startGesture(edgeHandle(tester));
    await wide.moveBy(const Offset(2000, 0));
    await wide.up();
    await tester.pump();

    expect(resized, [64, 600]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('double-clicking a handle fits the image again', (tester) async {
    final resized = await pump(tester, width: 240);

    await tester.tapAt(edgeHandle(tester));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(edgeHandle(tester));
    await tester.pumpAndSettle();

    expect(resized, [null]);
  });
}

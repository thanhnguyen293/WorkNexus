import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/hover_surface.dart';

void main() {
  final theme = buildAppTheme(
    variant: AppThemeVariant.light,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  );
  final colors = theme.extension<AppColors>()!;

  Widget app(Widget child) => MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    return gesture;
  }

  BoxDecoration decorationOf(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(HoverSurface),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return box.decoration! as BoxDecoration;
  }

  group('HoverSurface', () {
    testWidgets('tints the fill with hoverFill while the pointer is over it', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        app(
          HoverSurface(
            onTap: () => taps++,
            color: colors.card,
            child: const SizedBox.square(dimension: 40),
          ),
        ),
      );
      expect(decorationOf(tester).color, colors.card);

      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(HoverSurface)));
      await tester.pumpAndSettle();
      expect(
        decorationOf(tester).color,
        Color.alphaBlend(colors.hoverFill, colors.card),
      );

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(decorationOf(tester).color, colors.card);

      await tester.tap(find.byType(HoverSurface));
      expect(taps, 1);
    });

    testWidgets('tintOnHover false keeps the fill and swaps the border', (
      tester,
    ) async {
      final rest = Border.all(color: colors.border);
      final hover = Border.all(color: colors.borderStrong);
      await tester.pumpWidget(
        app(
          HoverSurface(
            onTap: () {},
            color: colors.card,
            tintOnHover: false,
            border: rest,
            hoverBorder: hover,
            child: const SizedBox.square(dimension: 40),
          ),
        ),
      );
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(HoverSurface)));
      await tester.pumpAndSettle();
      expect(decorationOf(tester).color, colors.card);
      expect(decorationOf(tester).border, hover);

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(decorationOf(tester).border, rest);
    });

    testWidgets('gives no hover feedback without a tap handler', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          HoverSurface(
            color: colors.card,
            child: const SizedBox.square(dimension: 40),
          ),
        ),
      );
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(HoverSurface)));
      await tester.pumpAndSettle();
      expect(decorationOf(tester).color, colors.card);
    });

    testWidgets('enabled opts a handler-less block into hover feedback', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          HoverSurface(
            enabled: true,
            color: colors.card,
            child: const SizedBox.square(dimension: 40),
          ),
        ),
      );
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(HoverSurface)));
      await tester.pumpAndSettle();
      expect(
        decorationOf(tester).color,
        Color.alphaBlend(colors.hoverFill, colors.card),
      );
    });
  });

  group('HoverRegion', () {
    testWidgets('reports enter and exit to its builder', (tester) async {
      await tester.pumpWidget(
        app(
          HoverRegion(
            builder: (context, hovered, _) => SizedBox.square(
              dimension: 40,
              child: Text(hovered ? 'in' : 'out'),
            ),
          ),
        ),
      );
      expect(find.text('out'), findsOneWidget);

      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(HoverRegion)));
      await tester.pump();
      expect(find.text('in'), findsOneWidget);

      await gesture.moveTo(Offset.zero);
      await tester.pump();
      expect(find.text('out'), findsOneWidget);
    });

    testWidgets('a disabled region never reports hover', (tester) async {
      await tester.pumpWidget(
        app(
          HoverRegion(
            enabled: false,
            builder: (context, hovered, _) => SizedBox.square(
              dimension: 40,
              child: Text(hovered ? 'in' : 'out'),
            ),
          ),
        ),
      );
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(HoverRegion)));
      await tester.pump();
      expect(find.text('out'), findsOneWidget);
    });
  });
}

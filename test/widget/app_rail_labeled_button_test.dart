import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_rail_labeled_button.dart';

void main() {
  final theme = buildAppTheme(
    variant: AppThemeVariant.light,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool selected,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: AppRailLabeledButton(
            leading: const Text('C'),
            label: 'Claude',
            tooltip: 'Claude · claude.ai',
            selected: selected,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('shows the name under the glyph and opens on tap', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, selected: false, onTap: () => taps++);

    final glyph = tester.getRect(find.text('C'));
    final name = tester.getRect(find.text('Claude'));
    expect(name.top, greaterThanOrEqualTo(glyph.bottom));
    expect(find.byTooltip('Claude · claude.ai'), findsOneWidget);

    await tester.tap(find.text('Claude'));
    expect(taps, 1);
  });

  testWidgets('a selected place is in the accent colour', (tester) async {
    await pump(tester, selected: true);
    final context = tester.element(find.text('Claude'));
    final accent = context.colors.accent;

    expect(tester.widget<Text>(find.text('Claude')).style?.color, accent);
    expect(
      DefaultTextStyle.of(tester.element(find.text('C'))).style.color,
      accent,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_count_badge.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/shell_pane/sidebar_primitives.dart';
import 'package:work_nexus/shared/shell_pane/sidebar_tree_rows.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('shows the count as a pill, with what it counts', (tester) async {
    await pump(
      tester,
      SidebarGroupToggle(
        label: 'Bugs',
        expanded: false,
        onTap: () {},
        count: 4,
      ),
    );
    expect(find.byType(AppCountBadge), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byTooltip('Assigned to me'), findsOneWidget);
  });

  testWidgets('shows nothing at zero', (tester) async {
    await pump(tester, const SidebarCountBadge(0));
    expect(find.byType(AppCountBadge), findsNothing);
  });
}

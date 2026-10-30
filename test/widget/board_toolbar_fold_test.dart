import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/tools/tool_module.dart';
import 'package:work_nexus/core/widgets/app_segmented_tabs.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/widgets/board_toolbar.dart';

void main() {
  final picked = <String>[];

  Widget harness(double width) {
    AppSegmentedTab scope(String label, {bool active = false}) =>
        AppSegmentedTab(
          label: label,
          active: active,
          onTap: () => picked.add(label),
        );
    return MaterialApp(
      locale: const Locale('en'),
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: BoardToolbar(
              filters: [
                scope('All', active: true),
                scope('Related to me'),
                scope('Due this week'),
              ],
              refresh: const SizedBox.square(dimension: 28),
              modes: [
                ToolViewMode(
                  id: const ViewModeId('board'),
                  label: (_) => 'Board',
                  icon: LucideIcons.columns3,
                ),
                ToolViewMode(
                  id: const ViewModeId('list'),
                  label: (_) => 'List',
                  icon: LucideIcons.list,
                ),
              ],
              viewMode: const ViewModeId('board'),
              onViewMode: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  setUp(picked.clear);

  testWidgets('a wide toolbar shows every scope and labelled view modes', (
    tester,
  ) async {
    await tester.pumpWidget(harness(1000));

    expect(tester.takeException(), isNull);
    expect(find.text('Related to me'), findsOneWidget);
    expect(find.text('Board'), findsOneWidget);
  });

  testWidgets('a narrower toolbar draws the view modes as icons first', (
    tester,
  ) async {
    await tester.pumpWidget(harness(600));

    expect(tester.takeException(), isNull);
    expect(find.text('Related to me'), findsOneWidget);
    expect(find.text('Board'), findsNothing);
    expect(find.byTooltip('Board'), findsOneWidget);
  });

  testWidgets('a narrow toolbar folds the scopes into a menu', (tester) async {
    await tester.pumpWidget(harness(240));

    expect(tester.takeException(), isNull);
    expect(find.text('Related to me'), findsNothing);
    expect(find.text('All'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Due this week'));
    await tester.pumpAndSettle();

    expect(picked, ['Due this week']);
  });
}

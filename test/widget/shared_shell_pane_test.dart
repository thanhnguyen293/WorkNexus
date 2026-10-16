import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/tools/tool_module.dart';
import 'package:work_nexus/core/widgets/hover_surface.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/shell_pane/feature_tab_strip.dart';
import 'package:work_nexus/shared/shell_pane/scope_filter_field.dart';
import 'package:work_nexus/shared/shell_pane/scope_list_body.dart';
import 'package:work_nexus/shared/shell_pane/scope_rows.dart';
import 'package:work_nexus/shared/shell_pane/tool_pane_scaffold.dart';

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('FeatureTabStrip & UnreadBadge', () {
    testWidgets('renders tabs, switches sections, and caps badge at 99+', (
      tester,
    ) async {
      final unreadCount99PlusProvider = Provider<int>((ref) => 150);
      final unreadCountSmallProvider = Provider<int>((ref) => 8);

      final sections = [
        ToolSection(
          id: const SectionId('tasks'),
          label: (l) => 'Tasks',
          icon: LucideIcons.checkSquare300,
          scopeKind: ScopeKind.project,
          unreadCount: unreadCountSmallProvider,
        ),
        ToolSection(
          id: const SectionId('bugs'),
          label: (l) => 'Bugs',
          icon: LucideIcons.bug300,
          scopeKind: ScopeKind.product,
          unreadCount: unreadCount99PlusProvider,
        ),
      ];

      SectionId selected = const SectionId('tasks');

      await tester.pumpWidget(
        _buildTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return FeatureTabStrip(
                sections: sections,
                selectedSectionId: selected,
                onSectionSelected: (id) => setState(() => selected = id),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Bugs'), findsOneWidget);

      // Verify unread badges
      expect(find.text('8'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);

      // Tap Bugs tab
      await tester.tap(find.text('Bugs'));
      await tester.pumpAndSettle();

      expect(selected, equals(const SectionId('bugs')));
    });
  });

  group('ScopeFilterField', () {
    testWidgets('debounces query input by 150ms and clears immediately', (
      tester,
    ) async {
      final emitted = <String>[];
      await tester.pumpWidget(
        _buildTestApp(ScopeFilterField(onChanged: emitted.add)),
      );
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(find.byType(TextField), 'work');
      // Before 150ms: nothing emitted yet
      await tester.pump(const Duration(milliseconds: 50));
      expect(emitted, isEmpty);

      // Advance past 150ms
      await tester.pump(const Duration(milliseconds: 110));
      expect(emitted, equals(['work']));

      // Tap clear icon
      await tester.tap(find.byIcon(LucideIcons.x300));
      await tester.pump();
      expect(emitted.last, equals(''));
    });
  });

  group('ScopeRow & ScopeQuickRow', () {
    testWidgets('renders selected and unselected row styles', (tester) async {
      var pinned = false;
      var rowTapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          Column(
            children: [
              ScopeRow(
                name: 'Project Alpha',
                path: 'mobile',
                count: 14,
                selected: true,
                isPinned: pinned,
                onPinToggle: () => pinned = !pinned,
                onTap: () => rowTapped = true,
              ),
              ScopeRow(name: 'Project Beta', onTap: () {}),
              ScopeQuickRow(
                label: 'All projects',
                icon: LucideIcons.layers300,
                count: 28,
                selected: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Project Alpha'), findsOneWidget);
      expect(find.text('/ mobile'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);

      // Verify selected row uses selectionFill
      final element = tester.element(find.text('Project Alpha'));
      final expectedSelectionFill = element.colors.selectionFill;

      final surfaces = tester
          .widgetList<HoverSurface>(find.byType(HoverSurface))
          .toList();
      expect(surfaces[0].color, equals(expectedSelectionFill));
      expect(surfaces[1].color, equals(Colors.transparent));
      expect(surfaces[2].color, equals(expectedSelectionFill));

      // Test pin toggle and tap
      await tester.tap(find.byIcon(LucideIcons.pin300));
      expect(pinned, isTrue);

      await tester.tap(find.text('Project Alpha'));
      expect(rowTapped, isTrue);
    });
  });

  group('ScopeListBody', () {
    testWidgets('caps list at 12 items and expands on Show all… click', (
      tester,
    ) async {
      final rows = List.generate(
        20,
        (i) =>
            ScopeRow(key: ValueKey('scope_$i'), name: 'Item $i', onTap: () {}),
      );

      await tester.pumpWidget(
        _buildTestApp(
          SizedBox(
            height: 600,
            child: ScopeListBody(
              groupTitle: 'All Projects',
              allRows: rows,
              showAllLabel: 'Show all 20 projects…',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First 12 items should be found, but 13th should not be rendered
      expect(find.byKey(const ValueKey('scope_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('scope_11')), findsOneWidget);
      expect(find.byKey(const ValueKey('scope_12')), findsNothing);

      // "Show all…" button is visible
      expect(find.text('Show all 20 projects…'), findsOneWidget);

      // Click "Show all…"
      await tester.tap(find.text('Show all 20 projects…'));
      await tester.pumpAndSettle();

      // Now item 12 should be rendered and Show all button gone
      expect(find.byKey(const ValueKey('scope_12')), findsOneWidget);
      expect(find.text('Show all 20 projects…'), findsNothing);
    });
  });

  group('ToolPaneScaffold', () {
    testWidgets('renders tabStrip and body within toolPaneWidth', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ToolPaneScaffold(
            tabStrip: Text('TabStripSlot'),
            body: Text('BodySlot'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TabStripSlot'), findsOneWidget);
      expect(find.text('BodySlot'), findsOneWidget);

      final scaffoldBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(scaffoldBox.width, equals(300.0));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/tools/tool_module.dart';
import 'package:work_nexus/core/widgets/app_button.dart';
import 'package:work_nexus/core/widgets/coming_soon_view.dart';
import 'package:work_nexus/core/widgets/view_mode_tab_bar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildAppTheme(
      variant: AppThemeVariant.light,
      surface: SurfaceStyle.outline,
      density: AppDensity.comfortable,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('ComingSoonView', () {
    testWidgets('renders icon, title, and body without action button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ComingSoonView(
            icon: LucideIcons.calendar300,
            title: 'Calendar view',
            body: 'Calendar view is coming soon to ZenTao Tasks.',
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.calendar300), findsOneWidget);
      expect(find.text('Calendar view'), findsOneWidget);
      expect(
        find.text('Calendar view is coming soon to ZenTao Tasks.'),
        findsOneWidget,
      );
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets(
      'renders action button and triggers onAction callback when tapped',
      (tester) async {
        var actionFired = false;

        await tester.pumpWidget(
          _buildTestApp(
            ComingSoonView(
              icon: LucideIcons.kanban300,
              title: 'Gantt chart',
              body: 'Gantt chart is currently in development.',
              actionLabel: 'Switch to Kanban',
              onAction: () => actionFired = true,
            ),
          ),
        );

        expect(find.text('Switch to Kanban'), findsOneWidget);
        expect(actionFired, isFalse);

        await tester.tap(find.text('Switch to Kanban'));
        await tester.pump();

        expect(actionFired, isTrue);
      },
    );
  });

  group('ViewModeTabBar', () {
    final testModes = [
      ToolViewMode(
        id: const ViewModeId('list'),
        label: (_) => 'List',
        icon: LucideIcons.list300,
      ),
      ToolViewMode(
        id: const ViewModeId('kanban'),
        label: (_) => 'Kanban',
        icon: LucideIcons.kanban300,
      ),
      ToolViewMode(
        id: const ViewModeId('calendar'),
        label: (_) => 'Calendar',
        icon: LucideIcons.calendar300,
      ),
    ];

    testWidgets('renders all view modes and highlights selected mode', (
      tester,
    ) async {
      ViewModeId? selected = const ViewModeId('kanban');

      await tester.pumpWidget(
        _buildTestApp(
          ViewModeTabBar(
            modes: testModes,
            selectedModeId: selected,
            onModeSelected: (modeId) => selected = modeId,
          ),
        ),
      );

      expect(find.text('List'), findsOneWidget);
      expect(find.text('Kanban'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.byIcon(LucideIcons.list300), findsOneWidget);
      expect(find.byIcon(LucideIcons.kanban300), findsOneWidget);
      expect(find.byIcon(LucideIcons.calendar300), findsOneWidget);

      // Tap on List
      await tester.tap(find.text('List'));
      await tester.pump();

      expect(selected, equals(const ViewModeId('list')));
    });

    testWidgets('supports keyboard navigation via arrow keys', (tester) async {
      ViewModeId? selected = const ViewModeId('list');

      await tester.pumpWidget(
        _buildTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return ViewModeTabBar(
                autofocus: true,
                modes: testModes,
                selectedModeId: selected,
                onModeSelected: (modeId) {
                  setState(() => selected = modeId);
                },
              );
            },
          ),
        ),
      );

      await tester.pump();

      // Send ArrowRight
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(selected, equals(const ViewModeId('kanban')));

      // Send ArrowRight again to reach Calendar
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(selected, equals(const ViewModeId('calendar')));

      // Send ArrowLeft to move back to Kanban
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(selected, equals(const ViewModeId('kanban')));
    });
  });
}

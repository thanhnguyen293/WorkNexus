import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_formatters.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_priority_badge.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_status_pill.dart';

void main() {
  Widget buildHarness(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
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

  group('ZenTaoFormatters', () {
    test('extractModule parses single and multiple bracketed modules', () {
      final (title1, mod1) = ZenTaoFormatters.extractModule(
        '[Backend] Implement OAuth2 login',
      );
      expect(title1, 'Implement OAuth2 login');
      expect(mod1, '[Backend]');

      final (title2, mod2) = ZenTaoFormatters.extractModule(
        '[Mobile][Feed] Layout overflow bug',
      );
      expect(title2, 'Layout overflow bug');
      expect(mod2, '[Mobile][Feed]');

      final (title3, mod3) = ZenTaoFormatters.extractModule(
        'Plain title without brackets',
      );
      expect(title3, 'Plain title without brackets');
      expect(mod3, isNull);
    });

    test('extractDeadline extracts deadline from ticket labels', () {
      final now = DateTime.now();
      final ticketWithDeadline = Ticket(
        id: 't1',
        accountId: 'acc1',
        projectId: 'p1',
        providerType: ProviderType.zentao,
        externalKey: '100',
        title: 'Task 1',
        body: 'Task body',
        status: UnifiedStatus.inprogress,
        providerStatus: 'doing',
        priority: Priority.urgent,
        sourceHash: 'hash',
        updatedAt: now,
        labels: ['deadline:2026-11-20'],
      );

      final extracted = ZenTaoFormatters.extractDeadline(ticketWithDeadline);
      expect(extracted, isNotNull);
      expect(extracted!.year, 2026);
      expect(extracted.month, 11);
      expect(extracted.day, 20);

      final formatted = ZenTaoFormatters.formatDeadline(extracted);
      expect(formatted, '2026-11-20');
    });

    test('calcDelayText computes overdue days accurately', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final delayText = ZenTaoFormatters.calcDelayText(pastDate);
      expect(delayText, startsWith('Delay'));
      expect(delayText, contains('days'));

      final futureDate = DateTime.now().add(const Duration(days: 5));
      expect(ZenTaoFormatters.calcDelayText(futureDate), isNull);
      expect(ZenTaoFormatters.calcDelayText(null), isNull);
    });
  });

  group('ZenTaoPriorityBadge', () {
    testWidgets('renders correct circle symbol for each priority', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHarness(
          const Row(
            children: [
              ZenTaoPriorityBadge(priority: Priority.urgent),
              ZenTaoPriorityBadge(priority: Priority.high),
              ZenTaoPriorityBadge(priority: Priority.medium),
              ZenTaoPriorityBadge(priority: Priority.low),
            ],
          ),
        ),
      );

      expect(find.text('①'), findsOneWidget);
      expect(find.text('②'), findsOneWidget);
      expect(find.text('③'), findsOneWidget);
      expect(find.text('④'), findsOneWidget);
    });
  });

  group('ZenTaoStatusPill', () {
    testWidgets('renders Doing for inprogress and Done for done status', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHarness(
          const Column(
            children: [
              ZenTaoStatusPill(
                status: UnifiedStatus.inprogress,
                providerStatus: 'doing',
              ),
              ZenTaoStatusPill(
                status: UnifiedStatus.done,
                providerStatus: 'done',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Doing'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}

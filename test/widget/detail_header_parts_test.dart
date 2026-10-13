import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/badges.dart';
import 'package:work_nexus/core/widgets/tinted_pill.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/detail_people.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/detail_status_line.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/task_effort_bar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

Ticket _ticket({String? assignee, TicketProviderEntity? entity}) => Ticket(
  id: 'zt:1',
  accountId: 'zt',
  projectId: 'zt:P',
  providerType: ProviderType.zentao,
  externalKey: '1',
  title: 't',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
  assignee: assignee,
  providerEntity: entity,
);

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
      ),
    );
  }

  group('DetailPeople', () {
    testWidgets('a bug shows who holds it and who reported it', (tester) async {
      await pump(
        tester,
        DetailPeople(
          ticket: _ticket(
            entity: const ZenTaoBugEntity(assignedTo: 'Thanh', openedBy: 'Lan'),
          ),
        ),
      );
      expect(find.text('Assigned to'), findsOneWidget);
      expect(find.text('Thanh'), findsOneWidget);
      expect(find.text('Opened by'), findsOneWidget);
      expect(find.text('Lan'), findsOneWidget);
    });

    testWidgets('a ticket nobody holds says so', (tester) async {
      await pump(tester, DetailPeople(ticket: _ticket()));
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('Opened by'), findsNothing);
    });
  });

  testWidgets('the status, priority and severity tags share one height', (
    tester,
  ) async {
    await pump(
      tester,
      DetailStatusLine(
        ticket: _ticket(
          entity: const ZenTaoBugEntity(confirmed: 1, activatedCount: 2),
        ).copyWith(priority: Priority.high, severity: 2),
      ),
    );
    final heights = {
      for (final finder in [
        find.byType(TintedPill).first,
        find.byType(PriorityTag),
        find.byType(SeverityTag),
      ])
        tester.getSize(finder).height,
    };
    expect(heights, hasLength(1), reason: '$heights');
  });

  group('TaskEffortBar', () {
    testWidgets('shows hours logged, left and estimated', (tester) async {
      await pump(
        tester,
        const TaskEffortBar(
          task: ZenTaoTaskEntity(estimate: 8, consumed: 6, left: 2.5),
        ),
      );
      expect(find.text('6 h logged so far'), findsOneWidget);
      expect(find.text('2.5 h left'), findsOneWidget);
      expect(find.text('Estimate 8 h'), findsOneWidget);
    });

    testWidgets('a task with no hours shows nothing', (tester) async {
      await pump(tester, const TaskEffortBar(task: ZenTaoTaskEntity()));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}

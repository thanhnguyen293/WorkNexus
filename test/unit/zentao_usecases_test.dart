import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/compute_zentao_metrics.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/is_due_this_week.dart';

void main() {
  group('IsDueThisWeek (ISO-8601 week boundary)', () {
    const isDue = IsDueThisWeek();

    test('correctly identifies days within Wednesday current week', () {
      final now = DateTime(2026, 10, 14, 15, 30); // Wednesday

      // Monday of this week
      expect(isDue(DateTime(2026, 10, 12), now: now), isTrue);
      // Wednesday of this week
      expect(isDue(DateTime(2026, 10, 14, 23, 59), now: now), isTrue);
      // Sunday end of this week
      expect(isDue(DateTime(2026, 10, 18, 23, 59, 59, 999), now: now), isTrue);

      // Previous Sunday (one second before Monday)
      expect(isDue(DateTime(2026, 10, 11, 23, 59, 59), now: now), isFalse);
      // Next Monday (one second after Sunday)
      expect(isDue(DateTime(2026, 10, 19), now: now), isFalse);
    });

    test(
      'Sunday boundary: Sunday is part of current week; Monday next week is not',
      () {
        final sundayNight = DateTime(2026, 10, 18, 23, 30); // Sunday

        expect(isDue(DateTime(2026, 10, 12, 8), now: sundayNight), isTrue);
        expect(isDue(DateTime(2026, 10, 18, 23, 59), now: sundayNight), isTrue);
        expect(
          isDue(DateTime(2026, 10, 19, 0, 0, 1), now: sundayNight),
          isFalse,
        );
      },
    );

    test(
      'Monday boundary: Monday starts new week; previous Sunday is not included',
      () {
        final mondayMorning = DateTime(2026, 10, 19, 6); // Monday

        expect(
          isDue(DateTime(2026, 10, 18, 23, 59, 59), now: mondayMorning),
          isFalse,
        );
        expect(isDue(DateTime(2026, 10, 19), now: mondayMorning), isTrue);
        expect(
          isDue(DateTime(2026, 10, 25, 23, 59), now: mondayMorning),
          isTrue,
        );
        expect(isDue(DateTime(2026, 10, 26), now: mondayMorning), isFalse);
      },
    );
  });

  group('ComputeZentaoMetrics', () {
    const compute = ComputeZentaoMetrics();
    const accountId = 'zentao-acc-1';
    const account = Account(
      id: accountId,
      workspaceId: 'ws',
      providerType: ProviderType.zentao,
      handle: 'thanh',
    );

    Ticket makeTicket({
      required String id,
      required String externalType,
      required UnifiedStatus status,
      required String providerStatus,
      String accId = accountId,
      String? assignee = 'Thanh',
      ProviderType provider = ProviderType.zentao,
      TicketProviderEntity? entity,
    }) {
      return Ticket(
        id: id,
        accountId: accId,
        projectId: 'p1',
        providerType: provider,
        externalKey: id,
        title: 'Ticket $id',
        body: '',
        priority: Priority.high,
        status: status,
        providerStatus: providerStatus,
        sourceHash: 'hash',
        externalType: externalType,
        providerEntity: entity,
        assignee: assignee,
      );
    }

    test('counts only my open tasks and bugs in the target account', () {
      final tickets = [
        // Open task
        makeTicket(
          id: '1',
          externalType: 'task',
          status: UnifiedStatus.todo,
          providerStatus: 'wait',
          entity: const TicketProviderEntity.zentaoTask(),
        ),
        // In-progress task
        makeTicket(
          id: '2',
          externalType: 'task',
          status: UnifiedStatus.inprogress,
          providerStatus: 'doing',
          entity: const TicketProviderEntity.zentaoTask(),
        ),
        // Closed/done task (should not count)
        makeTicket(
          id: '3',
          externalType: 'task',
          status: UnifiedStatus.done,
          providerStatus: 'done',
          entity: const TicketProviderEntity.zentaoTask(),
        ),
        // Cancelled task (should not count)
        makeTicket(
          id: '4',
          externalType: 'task',
          status: UnifiedStatus.blocked,
          providerStatus: 'cancel',
          entity: const TicketProviderEntity.zentaoTask(),
        ),
        // Open bug
        makeTicket(
          id: '5',
          externalType: 'bug',
          status: UnifiedStatus.todo,
          providerStatus: 'active',
          entity: const TicketProviderEntity.zentaoBug(),
        ),
        // Closed bug (should not count)
        makeTicket(
          id: '6',
          externalType: 'bug',
          status: UnifiedStatus.done,
          providerStatus: 'closed',
          entity: const TicketProviderEntity.zentaoBug(),
        ),
        // Task belonging to a different account (should not count)
        makeTicket(
          id: '7',
          accId: 'other-acc',
          externalType: 'task',
          status: UnifiedStatus.todo,
          providerStatus: 'wait',
        ),
        // Someone else's open task and bug (should not count)
        makeTicket(
          id: '9',
          externalType: 'task',
          status: UnifiedStatus.todo,
          providerStatus: 'wait',
          assignee: 'Kenny',
          entity: const TicketProviderEntity.zentaoTask(),
        ),
        makeTicket(
          id: '10',
          externalType: 'bug',
          status: UnifiedStatus.todo,
          providerStatus: 'active',
          assignee: 'thanhle',
          entity: const TicketProviderEntity.zentaoBug(),
        ),
        // Ticket from gitlab (should not count)
        makeTicket(
          id: '8',
          provider: ProviderType.gitlab,
          externalType: 'issue',
          status: UnifiedStatus.todo,
          providerStatus: 'opened',
        ),
      ];

      final metrics = compute(tickets: tickets, account: account);

      expect(metrics.primaryCount, equals(2)); // tasks 1 and 2
      expect(metrics.secondaryCount, equals(1)); // bug 5
    });
  });
}

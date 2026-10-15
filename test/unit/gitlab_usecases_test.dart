import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/tools/gitlab/domain/usecases/compute_gitlab_metrics.dart';

void main() {
  group('ComputeGitlabMetrics', () {
    const compute = ComputeGitlabMetrics();
    const accountId = 'gl-acc-1';

    Ticket makeTicket({
      required String id,
      required String externalType,
      required UnifiedStatus status,
      String accId = accountId,
      ProviderType provider = ProviderType.gitlab,
      TicketProviderEntity? entity,
    }) {
      return Ticket(
        id: id,
        accountId: accId,
        projectId: 'group/project',
        providerType: provider,
        externalKey: id,
        title: 'Item $id',
        body: '',
        priority: Priority.high,
        status: status,
        providerStatus: status == UnifiedStatus.done ? 'closed' : 'opened',
        sourceHash: 'hash',
        externalType: externalType,
        providerEntity: entity,
      );
    }

    test(
      'counts projects count and only open merge requests for target account',
      () {
        final tickets = [
          // Open MR
          makeTicket(
            id: '1',
            externalType: 'MergeRequest',
            status: UnifiedStatus.inprogress,
            entity: const TicketProviderEntity.gitlabItem(
              sourceBranch: 'feature',
              targetBranch: 'main',
            ),
          ),
          // Open Issue (should not count towards MR count)
          makeTicket(
            id: '2',
            externalType: 'Issue',
            status: UnifiedStatus.todo,
            entity: const TicketProviderEntity.gitlabItem(),
          ),
          // Closed/merged MR (should not count)
          makeTicket(
            id: '3',
            externalType: 'MergeRequest',
            status: UnifiedStatus.done,
            entity: const TicketProviderEntity.gitlabItem(),
          ),
          // MR for another account (should not count)
          makeTicket(
            id: '4',
            accId: 'other-acc',
            externalType: 'MergeRequest',
            status: UnifiedStatus.inprogress,
          ),
        ];

        final metrics = compute(
          tickets: tickets,
          projectCount: 5,
          accountId: accountId,
        );

        expect(metrics.primaryCount, equals(5)); // projects count
        expect(metrics.secondaryCount, equals(1)); // MR 1
      },
    );
  });
}

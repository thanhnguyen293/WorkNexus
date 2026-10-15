import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/tools/github/domain/usecases/compute_github_metrics.dart';

void main() {
  group('ComputeGithubMetrics', () {
    const compute = ComputeGithubMetrics();
    const accountId = 'gh-acc-1';

    Ticket makeTicket({
      required String id,
      required String externalType,
      required UnifiedStatus status,
      String accId = accountId,
      ProviderType provider = ProviderType.github,
      TicketProviderEntity? entity,
    }) {
      return Ticket(
        id: id,
        accountId: accId,
        projectId: 'owner/repo',
        providerType: provider,
        externalKey: id,
        title: 'Item $id',
        body: '',
        priority: Priority.high,
        status: status,
        providerStatus: status == UnifiedStatus.done ? 'closed' : 'open',
        sourceHash: 'hash',
        externalType: externalType,
        providerEntity: entity,
      );
    }

    test(
      'counts only open pull requests and open issues for target account',
      () {
        final tickets = [
          // Open PR
          makeTicket(
            id: '1',
            externalType: 'PullRequest',
            status: UnifiedStatus.inprogress,
            entity: const TicketProviderEntity.githubItem(
              headBranch: 'feature',
              baseBranch: 'main',
            ),
          ),
          // Open Issue
          makeTicket(
            id: '2',
            externalType: 'Issue',
            status: UnifiedStatus.todo,
            entity: const TicketProviderEntity.githubItem(),
          ),
          // Closed PR (should not count)
          makeTicket(
            id: '3',
            externalType: 'PullRequest',
            status: UnifiedStatus.done,
            entity: const TicketProviderEntity.githubItem(merged: true),
          ),
          // Closed Issue (should not count)
          makeTicket(
            id: '4',
            externalType: 'Issue',
            status: UnifiedStatus.done,
            entity: const TicketProviderEntity.githubItem(),
          ),
          // PR for a different account (should not count)
          makeTicket(
            id: '5',
            accId: 'other-acc',
            externalType: 'PullRequest',
            status: UnifiedStatus.inprogress,
          ),
          // Ticket from a different provider (should not count)
          makeTicket(
            id: '6',
            provider: ProviderType.gitlab,
            externalType: 'MergeRequest',
            status: UnifiedStatus.inprogress,
          ),
        ];

        final metrics = compute(tickets: tickets, accountId: accountId);

        expect(metrics.primaryCount, equals(1)); // PR 1
        expect(metrics.secondaryCount, equals(1)); // Issue 2
      },
    );
  });
}

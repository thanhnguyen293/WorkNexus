import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/tools/github/presentation/providers/github_scope.dart';
import 'package:work_nexus/tools/gitlab/presentation/providers/gitlab_scope.dart';

Ticket _t(
  String id,
  String accountId,
  ProviderType type,
  TicketProviderEntity entity,
) => Ticket(
  id: id,
  accountId: accountId,
  projectId: '$accountId:x',
  providerType: type,
  externalKey: id,
  title: id,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'opened',
  sourceHash: 'h',
  providerEntity: entity,
);

void main() {
  test('the GitLab board shows its account and open project only', () {
    final tickets = [
      _t(
        'a',
        'gl1',
        ProviderType.gitlab,
        const TicketProviderEntity.gitlabItem(
          projectPath: 'grp/web',
          projectId: 42,
        ),
      ),
      _t(
        'b',
        'gl1',
        ProviderType.gitlab,
        const TicketProviderEntity.gitlabItem(projectPath: 'grp/api'),
      ),
      _t(
        'c',
        'gl2',
        ProviderType.gitlab,
        const TicketProviderEntity.gitlabItem(projectPath: 'grp/web'),
      ),
    ];

    List<String> ids(String? scope) => [
      for (final t in scopeGitLabTickets(
        tickets,
        accountId: 'gl1',
        scopeId: scope,
      ))
        t.id,
    ];

    expect(ids(null), ['a', 'b']);
    expect(ids('grp/web'), ['a']);
    // The sidebar scopes by the numeric project id.
    expect(ids('42'), ['a']);
  });

  test('the GitHub board shows its account and open repository only', () {
    final tickets = [
      _t(
        'a',
        'gh1',
        ProviderType.github,
        const TicketProviderEntity.githubItem(repo: 'me/app'),
      ),
      _t(
        'b',
        'gh1',
        ProviderType.github,
        const TicketProviderEntity.githubItem(repo: 'me/lib'),
      ),
      _t(
        'c',
        'gh2',
        ProviderType.github,
        const TicketProviderEntity.githubItem(repo: 'me/app'),
      ),
    ];

    expect(
      [
        for (final t in scopeGitHubTickets(
          tickets,
          accountId: 'gh1',
          scopeId: 'me/app',
        ))
          t.id,
      ],
      ['a'],
    );
  });
}

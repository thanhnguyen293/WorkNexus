import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/tools/gitlab/presentation/util/gitlab_mr_phase.dart';

Ticket _mr(String status) => Ticket(
  id: 'mr',
  accountId: 'a',
  projectId: 'p',
  providerType: ProviderType.gitlab,
  externalKey: '1',
  title: 't',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.review,
  providerStatus: status,
  sourceHash: 'h',
);

void main() {
  const plain = GitLabItemEntity();

  test('reads the phase from the raw status', () {
    expect(gitLabMrPhase(_mr('merged'), plain), GitLabMrPhase.merged);
    expect(gitLabMrPhase(_mr('closed'), plain), GitLabMrPhase.closed);
    expect(gitLabMrPhase(_mr('draft'), plain), GitLabMrPhase.draft);
    expect(gitLabMrPhase(_mr('opened'), plain), GitLabMrPhase.open);
  });

  test('an opened MR flagged draft is a draft', () {
    expect(
      gitLabMrPhase(_mr('opened'), const GitLabItemEntity(draft: true)),
      GitLabMrPhase.draft,
    );
  });

  test('only draft and open are active', () {
    expect(GitLabMrPhase.values.where((p) => p.isActive), [
      GitLabMrPhase.draft,
      GitLabMrPhase.open,
    ]);
  });

  test('needs a rebase on need_rebase or when behind target', () {
    expect(
      gitLabMrNeedsRebase(const GitLabItemEntity(mergeStatus: 'need_rebase')),
      isTrue,
    );
    expect(
      gitLabMrNeedsRebase(
        const GitLabItemEntity(mergeStatus: 'mergeable', commitsBehind: 3),
      ),
      isTrue,
    );
    expect(
      gitLabMrNeedsRebase(const GitLabItemEntity(mergeStatus: 'mergeable')),
      isFalse,
    );
  });
}

/// Synthetic board-membership labels: the internal markers the list-sync paths
/// stamp onto a [Ticket] so a native board can scope its tickets from the local
/// DB (e.g. render offline) — `gitlab-project:<id>`, `github-repo:<slug>`,
/// `zentao-product:<id>`, the account-wide `gitlab-mine:<accountId>` /
/// `github-mine:<accountId>`, and `zentao-execution:<id>`.
///
/// The label *format* is a cross-feature contract: the sync layer writes it and
/// the board layer reads it, so both sides MUST go through the builders here
/// rather than re-spelling the strings. These labels are machinery, never shown
/// as tags — [kSyntheticLabelPrefixes] is what filters them out of the UI.
library;

/// Prefixes of every synthetic membership label. A provider's detail endpoint
/// doesn't return these, so a detail refresh must preserve them; the board and
/// card views strip them before rendering tags.
const List<String> kSyntheticLabelPrefixes = <String>[
  'zentao-product:',
  'zentao-execution:',
  'gitlab-project:',
  'github-repo:',
  'gitlab-mine:',
  'github-mine:',
];

String gitlabProjectLabel(String projectId) => 'gitlab-project:$projectId';

String gitlabMineLabel(String accountId) => 'gitlab-mine:$accountId';

String githubRepoLabel(String repoId) => 'github-repo:$repoId';

String githubMineLabel(String accountId) => 'github-mine:$accountId';

String zentaoProductLabel(String productId) => 'zentao-product:$productId';

String zentaoExecutionLabel(String executionId) =>
    'zentao-execution:$executionId';

import '../../../../core/domain/value_objects/linked_item_kind.dart';
import '../../../../core/domain/value_objects/provider_type.dart';

/// A merge/pull request or issue a link points to: [project] is the
/// `group/repo` path, [number] the MR / issue iid or PR / issue number.
typedef MergeRequestLink = ({
  ProviderType provider,
  LinkedItemKind kind,
  String host,
  String project,
  String number,
});

/// Recognises GitLab merge request and issue links
/// (`…/group/repo/-/merge_requests/12`, `…/-/issues/3`, any host — GitLab is
/// often self-hosted) and GitHub pull request and issue links
/// (`…/owner/repo/pull/12`, `…/issues/12`); trailing tabs such as `/diffs`
/// or `/files` and anchors such as `#note_1` are ignored. Anything else is
/// null.
class ParseMergeRequestLink {
  const ParseMergeRequestLink();

  static final _gitlab = RegExp(
    r'^/(.+?)/-/(merge_requests|issues)/(\d+)(?:[/?#].*)?$',
  );
  static final _github = RegExp(
    r'^/([^/]+/[^/]+)/(pull|issues)/(\d+)(?:[/?#].*)?$',
  );

  MergeRequestLink? call(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    final (provider, match) = switch ((
      _gitlab.firstMatch(uri.path),
      _github.firstMatch(uri.path),
    )) {
      (final m?, _) => (ProviderType.gitlab, m),
      // `owner/repo/issues/N` is common on other forges (Gitea, Bitbucket,
      // GitLab's old links), so an issue is GitHub's only on a GitHub host;
      // they keep their ordinary web preview.
      (_, final m?) when m[2] == 'pull' || _isGitHubHost(host) => (
        ProviderType.github,
        m,
      ),
      _ => (null, null),
    };
    if (provider == null || match == null) return null;
    return (
      provider: provider,
      kind: match[2] == 'issues'
          ? LinkedItemKind.issue
          : LinkedItemKind.mergeRequest,
      host: host,
      project: match[1]!,
      number: match[3]!,
    );
  }

  /// github.com, or a GitHub Enterprise host named like `github.acme.com`.
  static bool _isGitHubHost(String host) =>
      host == 'github.com' || host.startsWith('github.');

  /// Whether two links name the same item (case of host/path aside). GitLab
  /// numbers issues and MRs separately, so the kind must match; GitHub
  /// shares one number sequence between them (its `/issues/12` of a PR
  /// redirects to the PR), so there the number alone decides.
  static bool same(MergeRequestLink a, MergeRequestLink b) =>
      a.provider == b.provider &&
      (a.provider == ProviderType.github || a.kind == b.kind) &&
      a.host == b.host &&
      a.number == b.number &&
      a.project.toLowerCase() == b.project.toLowerCase();
}

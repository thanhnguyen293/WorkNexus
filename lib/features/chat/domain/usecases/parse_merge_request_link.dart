import '../../../../core/domain/value_objects/provider_type.dart';

/// A merge/pull request a link points to: [project] is the `group/repo`
/// path, [number] the MR iid / PR number.
typedef MergeRequestLink = ({
  ProviderType provider,
  String host,
  String project,
  String number,
});

/// Recognises GitLab merge request links (`…/group/repo/-/merge_requests/12`,
/// any host — GitLab is often self-hosted) and GitHub pull request links
/// (`…/owner/repo/pull/12`); trailing tabs such as `/diffs` or `/files` are
/// ignored. Anything else is null.
class ParseMergeRequestLink {
  const ParseMergeRequestLink();

  static final _gitlab = RegExp(r'^/(.+?)/-/merge_requests/(\d+)(?:[/?#].*)?$');
  static final _github = RegExp(r'^/([^/]+/[^/]+)/pull/(\d+)(?:[/?#].*)?$');

  MergeRequestLink? call(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    if (_gitlab.firstMatch(uri.path) case final m?) {
      return (
        provider: ProviderType.gitlab,
        host: host,
        project: m[1]!,
        number: m[2]!,
      );
    }
    if (_github.firstMatch(uri.path) case final m?) {
      return (
        provider: ProviderType.github,
        host: host,
        project: m[1]!,
        number: m[2]!,
      );
    }
    return null;
  }

  /// Whether two links name the same MR/PR (case of host/path aside).
  static bool same(MergeRequestLink a, MergeRequestLink b) =>
      a.provider == b.provider &&
      a.host == b.host &&
      a.number == b.number &&
      a.project.toLowerCase() == b.project.toLowerCase();
}

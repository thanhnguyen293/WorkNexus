import '../domain/value_objects/provider_type.dart';

/// Builds the browser-openable absolute URL for an inline image [rawUrl] taken
/// from a ticket description, used as a fallback when the in-app authenticated
/// fetch can't retrieve the bytes.
///
/// The motivating case is **GitLab < 17.4**: its markdown uploads render as a
/// project-relative `/uploads/<secret>/<file>` link served on a web route that
/// only accepts a session cookie — a Personal Access Token is rejected, and the
/// PAT-readable API endpoint doesn't exist before 17.4. The bytes therefore
/// can't be fetched in-app, but the user's browser (which has the session) can
/// open the web URL directly — for GitLab, `base/{projectPath}/uploads/…`.
///
/// Absolute URLs are returned unchanged; other relative links resolve against
/// the instance [baseUrl]. Returns null when it can't be resolved (no base).
String? providerImageWebUrl({
  required ProviderType providerType,
  required String? baseUrl,
  required String? projectPath,
  required String rawUrl,
}) {
  final parsed = Uri.tryParse(rawUrl);
  if (parsed != null && parsed.hasScheme) return rawUrl;
  final base = baseUrl?.trim();
  if (base == null || base.isEmpty) return null;
  final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  // GitLab renders a project upload as a project-relative `/uploads/…` link; the
  // browser reads it under the project's web path (with the user's session).
  if (providerType == ProviderType.gitlab &&
      projectPath != null &&
      projectPath.isNotEmpty &&
      rawUrl.startsWith('/uploads/')) {
    return '$root/$projectPath$rawUrl';
  }
  return rawUrl.startsWith('/') ? '$root$rawUrl' : '$root/$rawUrl';
}

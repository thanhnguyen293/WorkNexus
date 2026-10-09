part of 'gitlab_client.dart';

/// Authenticated inline-asset fetches (description images), mapping markdown
/// uploads onto the PAT-authenticated uploads API.
mixin _GitLabAssets on _GitLabClientBase {
  // ---- assets ----

  /// Fetches raw bytes for an authenticated inline asset — e.g. an `/uploads/…`
  /// image embedded in an issue/MR description. Only an image response is
  /// accepted (so an HTML error/login page is never rendered as an image);
  /// returns null on any non-image response or failure.
  ///
  /// GitLab renders a markdown upload as a **project-web-relative** link
  /// (`/uploads/<secret>/<file>`). That web path is served ONLY against a
  /// session cookie — a Personal Access Token is rejected there — so fetching it
  /// directly never works for a PAT integration. Instead we hit the **Markdown
  /// uploads API** (`GET /projects/:id/uploads/:secret/:filename`, GitLab 17.4+),
  /// which DOES honor the `PRIVATE-TOKEN` header. [projectId] (preferred) or
  /// [projectPath] identifies the owning project. Absolute URLs (and any
  /// non-upload relative link) are fetched as-is against the instance.
  Future<Uint8List?> fetchBytes(
    String url, {
    String? projectPath,
    int? projectId,
  }) async {
    final resolved = _resolveAsset(url, projectPath, projectId);
    final res = await _dio.getUri<List<int>>(
      resolved,
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final contentType = (res.headers.value('content-type') ?? '').toLowerCase();
    final data = res.data;
    if (res.statusCode == 200 &&
        data != null &&
        data.isNotEmpty &&
        contentType.startsWith('image')) {
      return Uint8List.fromList(data);
    }
    return null;
  }

  /// Resolves an inline-asset [url] from a description into an absolute URI.
  ///
  /// A bare project-relative markdown upload (`/uploads/<secret>/<file>`) is
  /// mapped to the Markdown uploads **API** endpoint for its project — the only
  /// PAT-authenticated way to read it (the web `/uploads/…` path needs a session
  /// cookie). The project ref is the numeric [projectId] when known, else the
  /// URL-encoded [projectPath]. Absolute URLs are used as-is; any other relative
  /// link resolves against the instance root.
  Uri _resolveAsset(String url, String? projectPath, int? projectId) {
    final parsed = Uri.parse(url);
    if (parsed.hasScheme) return parsed;
    final segments = parsed.pathSegments;
    final project = projectId != null && projectId > 0
        ? '$projectId'
        : (projectPath != null && projectPath.isNotEmpty ? projectPath : null);
    if (project != null &&
        segments.length >= 3 &&
        segments.first == 'uploads') {
      // `.replace(pathSegments:)` percent-encodes each segment (so a project
      // *path* like `group/web` becomes the `group%2Fweb` the API expects, and
      // any base-URL subpath is preserved).
      final base = Uri.parse(baseUrl);
      return base.replace(
        pathSegments: [
          ...base.pathSegments.where((s) => s.isNotEmpty),
          'api',
          'v4',
          'projects',
          project,
          'uploads',
          ...segments.skip(1),
        ],
      );
    }
    return Uri.parse('$baseUrl/').resolveUri(parsed);
  }
}

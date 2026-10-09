part of 'sync_service.dart';

/// Inline images, attachments and merge/pull request commits and changes.
mixin _TicketMedia on _SyncCore {
  // ---- detail view: commits + changed files ----

  @override
  Future<Result<List<RepoCommit>>> listMergeRequestCommits(
    Ticket ticket,
  ) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitLabAdapter) {
      return const Err(AuthFailure('No stored GitLab credentials'));
    }
    return adapter.listMergeRequestCommits(ticket);
  }

  @override
  Future<Result<List<RepoFileChange>>> listMergeRequestChanges(
    Ticket ticket,
  ) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitLabAdapter) {
      return const Err(AuthFailure('No stored GitLab credentials'));
    }
    return adapter.listMergeRequestChanges(ticket);
  }

  @override
  Future<Result<List<RepoCommit>>> listPullCommits(Ticket ticket) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitHubAdapter) {
      return const Err(AuthFailure('No stored GitHub credentials'));
    }
    return adapter.listPullCommits(ticket);
  }

  @override
  Future<Result<List<RepoFileChange>>> listPullFiles(Ticket ticket) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitHubAdapter) {
      return const Err(AuthFailure('No stored GitHub credentials'));
    }
    return adapter.listPullFiles(ticket);
  }

  // ---- inline image loading (authenticated + self-signed TLS) ----

  /// Successfully loaded inline-image bytes, keyed by account + url, so the detail
  /// panel reuses a loaded image instead of refetching on every Original/
  /// Translate tab switch. Only successes are cached, so a failed load can retry.
  /// LRU-bounded at 500 MB so it can't grow without limit over the app lifetime.
  final ByteLruCache _imageCache = ByteLruCache();

  /// Image loads in flight, so the same image shown in several places at once
  /// (description, comment, activity, a second open) is fetched only once.
  final _imagesInFlight = InFlight<String, Uint8List?>();

  /// Fetches the bytes for an inline image referenced by [ticket]'s rich text,
  /// via the ticket account's authenticated client (ZenTao session, GitLab or
  /// GitHub PAT). Returns null if the account has no stored credentials or the
  /// fetch fails. Only the matching provider's client is non-null. Successful
  /// results are cached in [_imageCache].
  @override
  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url) async {
    final key = '${ticket.accountId}|$url';
    final cached = _imageCache.get(key);
    if (cached != null) return cached;
    return _imagesInFlight.run(key, () async {
      final bytes = await _loadTicketImage(ticket, url);
      if (bytes != null) _imageCache.put(key, bytes);
      return bytes;
    });
  }

  Future<Uint8List?> _loadTicketImage(Ticket ticket, String url) async {
    try {
      final zen = await _zenClientFor(ticket.accountId);
      if (zen != null) return await zen.fetchBytes(url);
      final gitlab = await _gitlabClientFor(ticket.accountId);
      if (gitlab != null) {
        // A GitLab `/uploads/…` link is project-relative — pass the project ref
        // so the client fetches it via the PAT-readable Markdown uploads API.
        final (projectPath, projectId) = switch (ticket.providerEntity) {
          GitLabItemEntity(:final projectPath, :final projectId) => (
            projectPath,
            projectId,
          ),
          _ => (null, null),
        };
        return await gitlab.fetchBytes(
          url,
          projectPath: projectPath,
          projectId: projectId,
        );
      }
      final github = await _githubClientFor(ticket.accountId);
      if (github != null) return await github.fetchBytes(url);
    } catch (_) {}
    return null;
  }

  /// Downloads a ticket [attachment] through the account's authenticated client
  /// into a per-session temp cache and returns the local file path, so the
  /// in-app viewer can display images/videos directly. Returns null if the
  /// account lacks credentials or the download fails.
  @override
  Future<String?> cacheAttachment(Ticket ticket, TicketAttachment att) async {
    final client = await _zenClientFor(ticket.accountId);
    if (client == null) return null;
    try {
      final safeName = _safeName(att.title);
      // Reuse an already-downloaded file (viewer reopen, download after view).
      final existing = await _attachmentCache.existing(att.id, safeName);
      if (existing != null) return existing;
      final bytes = await client.downloadBytes(att.url);
      if (bytes == null) return null;
      return await _attachmentCache.store(att.id, safeName, bytes);
    } catch (_) {
      return null;
    }
  }

  /// Wipes the on-disk attachment cache. Call once at startup so downloaded
  /// repro videos/screenshots don't accumulate in temp across app sessions.
  Future<void> purgeAttachmentCache() => _attachmentCache.purge();

  /// Copies an already-[cachedPath] attachment into the user's Downloads folder
  /// and reveals it in Finder. Returns the saved path, or null on failure.
  @override
  Future<String?> saveAttachmentToDownloads(
    String cachedPath,
    String name,
  ) async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      final downloads = Directory('$home/Downloads');
      if (!await downloads.exists()) return null;
      final dest = File('${downloads.path}/${_safeName(name)}');
      await File(cachedPath).copy(dest.path);
      await Process.run('open', ['-R', dest.path]);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  String _safeName(String name) =>
      name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
}

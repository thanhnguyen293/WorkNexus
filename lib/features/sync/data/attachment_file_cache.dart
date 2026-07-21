import 'dart:io';
import 'dart:typed_data';

/// On-disk cache for downloaded ticket attachments (repro videos, screenshots),
/// backing [SyncService.cacheAttachment] so the in-app viewer reads a local
/// file instead of refetching. Two safeguards keep it from growing without
/// bound over time:
///
///  - [purge] wipes the whole directory once at startup, making it a true
///    per-session cache — within a session files are reused (no re-download),
///    across sessions the previous session's files are cleared.
///  - [store] enforces [maxBytes] (default 2 GB): after writing a new file it
///    deletes the oldest files (by last-modified time) until the directory fits
///    again, so one long session downloading many large videos can't fill the
///    disk.
class AttachmentFileCache {
  AttachmentFileCache({Directory? root, this.maxBytes = 2 * 1024 * 1024 * 1024})
    : _root =
          root ??
          Directory('${Directory.systemTemp.path}/worknexus_attachments');

  final Directory _root;

  /// Maximum total bytes retained across all cached files.
  final int maxBytes;

  /// The cached path for [id]+[safeName] if it is already on disk (non-empty),
  /// or null if it needs downloading.
  Future<String?> existing(String id, String safeName) async {
    final file = _fileFor(id, safeName);
    if (await file.exists() && await file.length() > 0) return file.path;
    return null;
  }

  /// Writes [bytes] for [id]+[safeName], evicts oldest files to stay under
  /// [maxBytes], and returns the local path.
  Future<String> store(String id, String safeName, Uint8List bytes) async {
    await _root.create(recursive: true);
    final file = _fileFor(id, safeName);
    await file.writeAsBytes(bytes, flush: true);
    await _enforceCap();
    return file.path;
  }

  /// Deletes the entire cache directory. Call once at startup so the cache is
  /// scoped to a single app session.
  Future<void> purge() async {
    try {
      if (await _root.exists()) await _root.delete(recursive: true);
    } catch (_) {
      // Best-effort: a locked/partially-removed temp dir must not block startup.
    }
  }

  File _fileFor(String id, String safeName) =>
      File('${_root.path}/${id}_$safeName');

  Future<void> _enforceCap() async {
    try {
      final entries = <(File, FileStat)>[];
      var total = 0;
      await for (final entity in _root.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        total += stat.size;
        entries.add((entity, stat));
      }
      if (total <= maxBytes) return;
      // Oldest download first, so the freshly written file survives eviction.
      entries.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (file, stat) in entries) {
        if (total <= maxBytes) break;
        try {
          await file.delete();
          total -= stat.size;
        } catch (_) {
          // Skip a file we can't remove; keep trying the rest.
        }
      }
    } catch (_) {
      // Never let cache housekeeping surface as an attachment failure.
    }
  }
}

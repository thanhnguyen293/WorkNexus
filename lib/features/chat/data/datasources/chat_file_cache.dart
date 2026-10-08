import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Chat attachments on disk (images, server thumbnails, videos, files), one
/// folder per chat account, so they are downloaded once and survive restarts.
///
/// Bounded by [maxBytes]: [trim] drops the least recently used files first.
/// "Used" is the modification time, which [open] bumps on every hit — access
/// times are not reliably kept by macOS or Windows. When no cache folder is
/// available every lookup misses and writes are skipped, so callers simply
/// download again.
class ChatFileCache {
  ChatFileCache({
    required Future<Directory> Function() root,
    this.maxBytes = 2 * 1024 * 1024 * 1024,
    this.trimEvery = const Duration(minutes: 10),
    DateTime Function() now = DateTime.now,
  }) : _root = root,
       _now = now;

  /// Under the OS cache folder (`~/Library/Caches/<app>` on macOS,
  /// `%LOCALAPPDATA%` on Windows). Also removes the temp folder earlier
  /// versions downloaded into.
  factory ChatFileCache.appDefault() => ChatFileCache(
    root: () async {
      final legacy = Directory(
        '${(await getTemporaryDirectory()).path}/worknexus_chat',
      );
      unawaited(_deleteQuietly(legacy));
      final base = await getApplicationCacheDirectory();
      return Directory('${base.path}/chat_files');
    },
  );

  final Future<Directory> Function() _root;
  final int maxBytes;

  /// At most one automatic [trim] per this long.
  final Duration trimEvery;
  final DateTime Function() _now;

  Future<Directory?>? _dir;
  DateTime? _lastTrim;
  Future<void>? _trimming;

  Future<Directory?> _base() =>
      _dir ??= _root().then<Directory?>((d) => d, onError: (Object _) => null);

  /// Where [name] of account [accountId] lives; it may not exist yet. Null
  /// when there is no cache folder.
  Future<File?> fileFor(String accountId, String name) async {
    final base = await _base();
    if (base == null) return null;
    final sep = Platform.pathSeparator;
    return File('${base.path}$sep${_safe(accountId)}$sep${_safe(name)}');
  }

  /// The cached file, marked as just used; null when it is not cached.
  Future<File?> open(String accountId, String name) async {
    final file = await fileFor(accountId, name);
    if (file == null) return null;
    try {
      if (!await file.exists() || await file.length() == 0) return null;
      await file.setLastModified(_now());
      return file;
    } on FileSystemException {
      return null;
    }
  }

  Future<Uint8List?> read(String accountId, String name) async {
    final file = await open(accountId, name);
    try {
      return await file?.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  /// Stores [bytes]; returns the file, or null when it could not be written
  /// (the caller still has the bytes, so that is not an error).
  Future<File?> write(String accountId, String name, Uint8List bytes) async {
    final file = await fileFor(accountId, name);
    if (file == null) return null;
    try {
      await file.parent.create(recursive: true);
      // Write beside and rename, so a crash never leaves a truncated file
      // that later reads would take for the real one.
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
      await file.setLastModified(_now());
    } on FileSystemException {
      return null;
    }
    trimSoon();
    return file;
  }

  /// Runs [trim] unless one ran within [trimEvery].
  void trimSoon() {
    final last = _lastTrim;
    if (last != null && _now().difference(last) < trimEvery) return;
    _lastTrim = _now();
    unawaited(trim());
  }

  /// Deletes least recently used files until the cache is within 90% of
  /// [maxBytes] (the slack keeps every new download from triggering a trim).
  Future<void> trim() =>
      _trimming ??= _trim().whenComplete(() => _trimming = null);

  Future<void> _trim() async {
    final base = await _base();
    if (base == null) return;
    final entries = <({File file, int size, DateTime used})>[];
    var total = 0;
    try {
      if (!await base.exists()) return;
      await for (final entity in base.list(recursive: true)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        entries.add((file: entity, size: stat.size, used: stat.modified));
        total += stat.size;
      }
    } on FileSystemException {
      return;
    }
    if (total <= maxBytes) return;
    entries.sort((a, b) => a.used.compareTo(b.used));
    final target = maxBytes * 9 ~/ 10;
    for (final e in entries) {
      if (total <= target) break;
      try {
        await e.file.delete();
        total -= e.size;
      } on FileSystemException {
        // In use (e.g. a video playing on Windows): try again next trim.
      }
    }
  }

  static Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // Left for the OS to clean up.
    }
  }

  static String _safe(String name) =>
      name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '_');
}

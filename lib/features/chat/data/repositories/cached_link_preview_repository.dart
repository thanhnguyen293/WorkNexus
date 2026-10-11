import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/link_preview.dart';
import '../../domain/repositories/link_preview_repository.dart';
import '../datasources/link_preview_http_datasource.dart';
import '../datasources/link_preview_local_datasource.dart';
import '../mappers/link_preview_mappers.dart';

/// Link previews from drift first, the web only when missing or stale.
///
/// A fetched preview (or "nothing to show") is stored, so it shows at once
/// after a restart. A failed fetch is never stored nor kept in memory: the
/// next look retries it. When a stale preview cannot be refreshed, the old
/// one is still shown.
class CachedLinkPreviewRepository implements LinkPreviewRepository {
  CachedLinkPreviewRepository({
    required LinkPreviewLocalDatasource local,
    required LinkPreviewHttpDatasource http,
    DateTime Function() now = DateTime.now,
  }) : _local = local,
       _http = http,
       _now = now;

  /// Pages change rarely; a week-old preview is refetched on next view.
  static const maxAge = Duration(days: 7);

  /// Previews not refreshed for this long (so not viewed for weeks) are
  /// deleted.
  static const keepFor = Duration(days: 30);

  /// In-flight and recent lookups, so a link shown in many messages is read
  /// (and fetched) once.
  static const _maxInMemory = 300;

  final LinkPreviewLocalDatasource _local;
  final LinkPreviewHttpDatasource _http;
  final DateTime Function() _now;
  final _memory = <String, Future<Result<LinkPreview?>>>{};

  @override
  Future<Result<LinkPreview?>> preview(String url) {
    final cached = _memory.remove(url);
    if (cached != null) return _memory[url] = cached;
    if (_memory.length >= _maxInMemory) _memory.remove(_memory.keys.first);
    final lookup = _load(url);
    _memory[url] = lookup;
    lookup.then((result) {
      if (result is Err && identical(_memory[url], lookup)) {
        _memory.remove(url);
      }
    });
    return lookup;
  }

  Future<Result<LinkPreview?>> _load(String url) async {
    final stored = await _stored(url);
    if (stored != null && _now().difference(stored.fetchedAt) < maxAge) {
      return Ok(stored.preview);
    }
    final fetched = await _http.fetch(url);
    switch (fetched) {
      case Ok(:final value):
        await _store(url, value);
        return fetched;
      case Err():
        return stored == null ? fetched : Ok(stored.preview);
    }
  }

  /// The stored preview, or null when there is none (or the DB failed —
  /// the web is then the fallback).
  Future<({LinkPreview? preview, DateTime fetchedAt})?> _stored(
    String url,
  ) async {
    try {
      final row = await _local.find(url);
      if (row == null) return null;
      return (preview: linkPreviewFromRow(row), fetchedAt: row.fetchedAt);
    } on Exception catch (e, s) {
      appTalker.handle(e, s, 'Could not read link preview');
      return null;
    }
  }

  Future<void> _store(String url, LinkPreview? preview) async {
    final now = _now();
    try {
      await _local.save(linkPreviewToRow(url, preview, fetchedAt: now));
      await _local.deleteOlderThan(now.subtract(keepFor));
    } on Exception catch (e, s) {
      // Still shown from memory; it is just fetched again next launch.
      appTalker.handle(e, s, 'Could not store link preview');
    }
  }
}

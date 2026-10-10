import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/domain/adapters/provider_adapter.dart';

/// Drift access to the last-fetched provider container lists
/// ([SourceListSnapshots]), so the sidebar tree can paint from disk on launch
/// and refresh from the network behind it.
class SourceListCache {
  const SourceListCache(this._db);

  static const _products = 'products';
  static const _projects = 'projects';

  final AppDatabase _db;

  Future<List<ProviderProduct>?> readProducts(String accountId) async {
    final items = await _read(accountId, _products);
    return items
        ?.map(
          (e) => ProviderProduct(id: e.id, name: e.name, accountId: accountId),
        )
        .toList();
  }

  Future<List<ProviderProject>?> readProjects(String accountId) async {
    final items = await _read(accountId, _projects);
    return items
        ?.map(
          (e) => ProviderProject(id: e.id, name: e.name, accountId: accountId),
        )
        .toList();
  }

  Future<void> saveProducts(String accountId, List<ProviderProduct> items) =>
      _save(accountId, _products, [for (final p in items) (p.id, p.name)]);

  Future<void> saveProjects(String accountId, List<ProviderProject> items) =>
      _save(accountId, _projects, [for (final p in items) (p.id, p.name)]);

  Future<List<({String id, String name})>?> _read(
    String accountId,
    String kind,
  ) async {
    final row =
        await (_db.select(_db.sourceListSnapshots)..where(
              (s) => s.accountId.equals(accountId) & s.kind.equals(kind),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    // A snapshot is only a head start for the network fetch that follows, so
    // an unreadable one is treated as a cache miss rather than an error.
    try {
      return [
        for (final e in jsonDecode(row.json) as List<dynamic>)
          (
            id: (e as Map<String, dynamic>)['id'] as String,
            name: e['name'] as String,
          ),
      ];
    } on Object {
      return null;
    }
  }

  Future<void> _save(
    String accountId,
    String kind,
    List<(String, String)> items,
  ) => _db
      .into(_db.sourceListSnapshots)
      .insertOnConflictUpdate(
        SourceListSnapshotsCompanion.insert(
          accountId: accountId,
          kind: kind,
          json: jsonEncode([
            for (final (id, name) in items) {'id': id, 'name': name},
          ]),
          fetchedAt: DateTime.now(),
        ),
      );
}

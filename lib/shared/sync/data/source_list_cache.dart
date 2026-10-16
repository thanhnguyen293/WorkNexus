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
    // Snapshots saved before the grouping was kept have no program / line:
    // those products read back ungrouped until the next fetch.
    return items
        ?.map(
          (e) => ProviderProduct(
            id: e.id,
            name: e.name,
            accountId: accountId,
            programId: e.extra['programId'],
            programName: e.extra['programName'],
            lineId: e.extra['lineId'],
            lineName: e.extra['lineName'],
          ),
        )
        .toList();
  }

  Future<List<ProviderProject>?> readProjects(String accountId) async {
    final items = await _read(accountId, _projects);
    // Older snapshots have no program: read back ungrouped.
    return items
        ?.map(
          (e) => ProviderProject(
            id: e.id,
            name: e.name,
            accountId: accountId,
            programId: e.extra['programId'],
            programName: e.extra['programName'],
          ),
        )
        .toList();
  }

  /// Program names a fetch could not get (`/programs` failing this time)
  /// from the last list that had them, so the grouping does not come and go.
  Future<List<ProviderProject>> withKnownProgramNames(
    String accountId,
    List<ProviderProject> projects,
  ) async {
    if (!projects.any((p) => p.programId != null && p.programName == null)) {
      return projects;
    }
    final cached = await readProjects(accountId) ?? const <ProviderProject>[];
    final known = <String, String>{
      for (final p in cached)
        if ((p.programId, p.programName) case (final id?, final name?))
          id: name,
    };
    return [
      for (final p in projects)
        ProviderProject(
          id: p.id,
          name: p.name,
          accountId: p.accountId,
          programId: p.programId,
          programName: p.programName ?? known[p.programId],
        ),
    ];
  }

  Future<void> saveProducts(String accountId, List<ProviderProduct> items) =>
      _save(accountId, _products, [
        for (final p in items)
          {
            'id': p.id,
            'name': p.name,
            'programId': ?p.programId,
            'programName': ?p.programName,
            'lineId': ?p.lineId,
            'lineName': ?p.lineName,
          },
      ]);

  Future<void> saveProjects(String accountId, List<ProviderProject> items) =>
      _save(accountId, _projects, [
        for (final p in items)
          {
            'id': p.id,
            'name': p.name,
            'programId': ?p.programId,
            'programName': ?p.programName,
          },
      ]);

  Future<List<({String id, String name, Map<String, String> extra})>?> _read(
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
            extra: {
              for (final MapEntry(:key, :value) in e.entries)
                if (value is String && key != 'id' && key != 'name') key: value,
            },
          ),
      ];
    } on Object {
      return null;
    }
  }

  Future<void> _save(
    String accountId,
    String kind,
    List<Map<String, String>> items,
  ) => _db
      .into(_db.sourceListSnapshots)
      .insertOnConflictUpdate(
        SourceListSnapshotsCompanion.insert(
          accountId: accountId,
          kind: kind,
          json: jsonEncode(items),
          fetchedAt: DateTime.now(),
        ),
      );
}

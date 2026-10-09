import 'package:drift/drift.dart' show Table, TableInfo;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/data/local/database_seeder.dart';
import 'package:work_nexus/data/local/mappers.dart';
import 'package:work_nexus/features/connections/data/repositories/drift_local_cache_repository.dart';
import 'package:work_nexus/features/connections/domain/entities/cache_section.dart';

void main() {
  late AppDatabase db;
  late DriftLocalCacheRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftLocalCacheRepository(db);
    await seedDatabaseIfEmpty(db, now: DateTime(2026, 7, 17, 12));
    await db.saveSettings(appSettingsToCompanion(const AppSettings()));
  });
  tearDown(() => db.close());

  Future<int> count(TableInfo<Table, Object?> table) =>
      db.select(table).get().then((rows) => rows.length);

  test('clears only the picked sections', () async {
    expect(await count(db.tickets), greaterThan(0));
    expect(await count(db.translations), greaterThan(0));

    expect(await repo.clear({CacheSection.tickets}), isA<Ok<void>>());

    expect(await count(db.tickets), 0);
    expect(await count(db.comments), 0);
    expect(await count(db.activities), 0);
    expect(await count(db.projects), 0);
    // Not picked: still there.
    expect(await count(db.translations), greaterThan(0));
  });

  test('never touches accounts, workspaces or settings', () async {
    final accounts = await count(db.accounts);
    final workspaces = await count(db.workspaces);

    await repo.clear({...CacheSection.values});

    expect(await count(db.tickets), 0);
    expect(await count(db.translations), 0);
    expect(await count(db.accounts), accounts);
    expect(await count(db.workspaces), workspaces);
    expect(await db.getSettings(), isNotNull);
  });
}

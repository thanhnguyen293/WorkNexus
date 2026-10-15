import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/database/database_seeder.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('the demo purge removes the seeded rows and nothing else', () async {
    await seedDatabaseIfEmpty(db, now: DateTime(2026, 7, 17, 12));
    await db
        .into(db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            id: 'mine',
            name: 'Mine',
            shortCode: 'M',
            colorValue: 0xFF336699,
            sortOrder: const Value(9),
          ),
        );

    final removed = await purgeSeededDemoData(db);

    expect(removed, greaterThan(0));
    expect(await db.countTickets(), 0);
    expect(await db.select(db.accounts).get(), isEmpty);
    expect((await db.select(db.workspaces).get()).single.id, 'mine');
    expect(await purgeSeededDemoData(db), 0, reason: 'idempotent');
  });
}

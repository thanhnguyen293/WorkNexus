import 'package:drift/drift.dart';

import '../../core/database/database.dart';
import '../fixtures/design_seed.dart';
import 'mappers.dart';

/// Removes the seeded demo dataset (workspaces `personal/compA/compB` and their
/// accounts/projects/tickets/comments/translations) from an existing database,
/// leaving any real user-connected accounts and their data intact. Idempotent —
/// a no-op once the demo rows are gone. Returns the number of tickets removed.
Future<int> purgeSeededDemoData(AppDatabase db) async {
  final seed = SeedData.build();
  final accountIds = seed.accounts.map((a) => a.id).toList();
  final workspaceIds = seed.workspaces.map((w) => w.id).toList();

  // Fast path: nothing to do if no demo account is present.
  final present = await (db.select(
    db.accounts,
  )..where((a) => a.id.isIn(accountIds))).get();
  if (present.isEmpty) return 0;

  var removed = 0;
  await db.transaction(() async {
    for (final acc in accountIds) {
      await (db.delete(
        db.comments,
      )..where((c) => c.ticketId.like('$acc:%'))).go();
      await (db.delete(
        db.translations,
      )..where((t) => t.ticketId.like('$acc:%'))).go();
      removed += await (db.delete(
        db.tickets,
      )..where((t) => t.accountId.equals(acc))).go();
      await (db.delete(
        db.projects,
      )..where((p) => p.accountId.equals(acc))).go();
      await (db.delete(db.accounts)..where((a) => a.id.equals(acc))).go();
    }
    for (final ws in workspaceIds) {
      await (db.delete(db.workspaces)..where((w) => w.id.equals(ws))).go();
    }
  });
  return removed;
}

/// Populates the drift database from the design dataset on first run only.
Future<void> seedDatabaseIfEmpty(AppDatabase db, {DateTime? now}) async {
  if (await db.countTickets() > 0) return;
  final seed = SeedData.build(now: now);
  await db.batch((b) {
    for (var i = 0; i < seed.workspaces.length; i++) {
      b.insert(db.workspaces, workspaceToCompanion(seed.workspaces[i], i));
    }
    for (final a in seed.accounts) {
      b.insert(db.accounts, accountToCompanion(a));
    }
    for (final p in seed.projects) {
      b.insert(db.projects, projectToCompanion(p));
    }
    for (final t in seed.tickets) {
      b.insert(db.tickets, ticketToCompanion(t));
    }
    for (final tr in seed.translations) {
      b.insert(db.translations, translationToCompanion(tr));
    }
  });
}

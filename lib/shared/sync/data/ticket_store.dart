import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../core/data/mappers/mappers.dart';
import '../../../core/database/database.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/activity_event.dart';
import '../../../core/domain/entities/comment.dart';
import '../../../core/domain/entities/project.dart';
import '../../../core/domain/entities/ticket.dart';
import 'merge_detail_labels.dart';

/// Writes what a sync fetched into the ticket tables — only the rows that
/// differ from what is stored. Every write re-runs the drift watches over its
/// table and re-renders whatever reads them (the board, every card, the open
/// panel), so a page or a refresh that brings nothing new must leave the
/// tables untouched. Rows are compared in their stored form (see
/// [ticketAsStored]).
class TicketStore {
  TicketStore(this._db);

  final AppDatabase _db;

  /// The stored tickets among [ids], by id.
  Future<Map<String, Ticket>> stored(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const {};
    final rows = await (_db.select(
      _db.tickets,
    )..where((r) => r.id.isIn(list))).get();
    return {for (final r in rows) r.id: ticketFromRow(r)};
  }

  /// Stores [account], the projects its [tickets] name, and the tickets a
  /// list sync fetched. Carries forward the synthetic board-membership labels
  /// ([kSyntheticLabelPrefixes]) already stored for these tickets: each list
  /// sync only stamps its own marker (a project board vs. the account-wide
  /// "mine" board), and overwriting the row would otherwise drop the others —
  /// leaving an item missing from a board it belongs to when the board
  /// renders from the DB offline. Real provider labels still come fresh from
  /// the server; stale markers reconcile online via each board's slice.
  Future<void> writeSynced(Account account, List<Ticket> tickets) async {
    final prior = await stored([for (final t in tickets) t.id]);
    final changedTickets = <Ticket>[];
    for (final t in tickets) {
      final merged = switch (prior[t.id]) {
        final stored? => t.copyWith(
          labels: mergeDetailLabels(t.labels, stored.labels),
        ),
        null => t,
      };
      if (prior[t.id] != ticketAsStored(merged)) changedTickets.add(merged);
    }

    final projects = <String, Project>{};
    for (final t in tickets) {
      projects.putIfAbsent(
        t.projectId,
        () => Project(
          id: t.projectId,
          accountId: account.id,
          name: t.projectId.split(':').skip(1).join(':'),
        ),
      );
    }
    final storedProjects = await (_db.select(
      _db.projects,
    )..where((p) => p.id.isIn(projects.keys.toList()))).get();
    final storedProjectById = {
      for (final r in storedProjects) r.id: projectFromRow(r),
    };
    final changedProjects = [
      for (final p in projects.values)
        if (storedProjectById[p.id] != p) p,
    ];

    final storedAccount = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(account.id))).getSingleOrNull();
    final accountChanged =
        storedAccount == null || accountFromRow(storedAccount) != account;

    if (!accountChanged && changedProjects.isEmpty && changedTickets.isEmpty) {
      return;
    }
    await _db.batch((b) {
      if (accountChanged) {
        b.insert(
          _db.accounts,
          accountToCompanion(account),
          onConflict: DoUpdate((_) => accountToCompanion(account)),
        );
      }
      for (final p in changedProjects) {
        b.insert(
          _db.projects,
          projectToCompanion(p),
          onConflict: DoUpdate((_) => projectToCompanion(p)),
        );
      }
      for (final t in changedTickets) {
        b.insert(
          _db.tickets,
          ticketToCompanion(t),
          onConflict: DoUpdate((_) => ticketToCompanion(t)),
        );
      }
    });
  }

  /// Stores [ticket] unless its row already reads the same. Compared against
  /// the row, not the caller's copy: after an optimistic update the row holds
  /// the guess, and the server's answer must replace it even when it equals
  /// what the caller started from.
  Future<void> writeIfChanged(Ticket ticket) async {
    final prior = (await stored([ticket.id]))[ticket.id];
    if (prior == ticketAsStored(ticket)) return;
    await _db
        .into(_db.tickets)
        .insertOnConflictUpdate(ticketToCompanion(ticket));
  }

  /// Replaces the provider's comments on [ticketId] with [comments] (the
  /// user's internal notes stay), unless the stored set already matches.
  Future<void> replaceProviderComments(
    String ticketId,
    List<Comment> comments,
  ) async {
    final rows =
        await (_db.select(_db.comments)..where(
              (c) => c.ticketId.equals(ticketId) & c.origin.equals('provider'),
            ))
            .get();
    final prior = {for (final r in rows) r.id: commentFromRow(r)};
    final fresh = {for (final c in comments) c.id: commentAsStored(c)};
    if (const MapEquality<String, Comment>().equals(prior, fresh)) return;
    await (_db.delete(_db.comments)..where(
          (c) => c.ticketId.equals(ticketId) & c.origin.equals('provider'),
        ))
        .go();
    await _db.batch(
      (b) => b.insertAllOnConflictUpdate(_db.comments, [
        for (final c in comments) commentToCompanion(c),
      ]),
    );
  }

  /// Replaces the activity of [ticketId] with [events], unless the stored
  /// set already matches.
  Future<void> replaceActivity(
    String ticketId,
    List<ActivityEvent> events,
  ) async {
    final rows = await (_db.select(
      _db.activities,
    )..where((a) => a.ticketId.equals(ticketId))).get();
    final prior = {for (final r in rows) r.id: activityFromRow(r)};
    final fresh = {for (final e in events) e.id: activityAsStored(e)};
    if (const MapEquality<String, ActivityEvent>().equals(prior, fresh)) return;
    await (_db.delete(
      _db.activities,
    )..where((a) => a.ticketId.equals(ticketId))).go();
    await _db.batch(
      (b) => b.insertAllOnConflictUpdate(_db.activities, [
        for (final e in events) activityToCompanion(e),
      ]),
    );
  }
}

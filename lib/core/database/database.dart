import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'database_location.dart';

part 'database.g.dart';
part 'database_board_tables.dart';
part 'database_chat_tables.dart';
part 'database_migrations.dart';

@DriftDatabase(
  tables: [
    Workspaces,
    Accounts,
    Projects,
    Tickets,
    Comments,
    Translations,
    Settings,
    Activities,
    SavedFilters,
    ChatAccounts,
    ChatConversations,
    ChatMessages,
    ChatUsers,
    ZenTaoProfiles,
    ChatMessageTranslations,
  ],
)
class AppDatabase extends _$AppDatabase with _Migrations {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  static QueryExecutor _openDefault() => driftDatabase(
    name: kDatabaseName,
    native: const DriftNativeOptions(
      databaseDirectory: resolveDatabaseDirectory,
    ),
  );

  @override
  int get schemaVersion => 36;

  // ---- reactive reads ----
  Stream<List<TicketRow>> watchTickets() => select(tickets).watch();
  Stream<List<WorkspaceRow>> watchWorkspaces() => (select(
    workspaces,
  )..orderBy([(w) => OrderingTerm(expression: w.sortOrder)])).watch();
  Stream<List<AccountRow>> watchAccounts() => select(accounts).watch();
  Stream<List<ProjectRow>> watchProjects() => select(projects).watch();
  Stream<List<CommentRow>> watchComments(String ticketId) =>
      (select(comments)..where((c) => c.ticketId.equals(ticketId))).watch();
  Stream<List<ActivityRow>> watchActivity(String ticketId) =>
      (select(activities)
            ..where((a) => a.ticketId.equals(ticketId))
            ..orderBy([(a) => OrderingTerm(expression: a.at)]))
          .watch();

  /// The board's saved filter presets, newest first.
  Stream<List<SavedFilterRow>> watchSavedFilters() =>
      (select(savedFilters)..orderBy([
            (f) =>
                OrderingTerm(expression: f.createdAt, mode: OrderingMode.desc),
          ]))
          .watch();

  Stream<TranslationRow?> watchTranslation(String ticketId) => (select(
    translations,
  )..where((t) => t.ticketId.equals(ticketId))).watchSingleOrNull();

  Future<int> countTickets() async {
    final c = countAll();
    final q = selectOnly(tickets)..addColumns([c]);
    return q.map((r) => r.read(c)!).getSingle();
  }

  // ---- app settings (single row, id = 0) ----
  Future<SettingRow?> getSettings() =>
      (select(settings)..where((s) => s.id.equals(0))).getSingleOrNull();

  Future<void> saveSettings(SettingsCompanion value) =>
      into(settings).insertOnConflictUpdate(value.copyWith(id: const Value(0)));
}

/// Helpers for encoding the labels list column.
List<String> decodeLabels(String json) =>
    (jsonDecode(json) as List).cast<String>();
String encodeLabels(List<String> labels) => jsonEncode(labels);

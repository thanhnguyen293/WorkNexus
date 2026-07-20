import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('WorkspaceRow')
class Workspaces extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get shortCode => text()();
  IntColumn get colorValue => integer()();
  BoolColumn get isPersonal => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get providerType => text()();
  TextColumn get handle => text()();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get credentialsRef => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get name => text()();
  TextColumn get externalId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TicketRow')
class Tickets extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get projectId => text()();
  TextColumn get providerType => text()();
  TextColumn get externalKey => text()();
  TextColumn get externalType => text().nullable()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  IntColumn get priorityLevel => integer()();
  TextColumn get statusNorm => text()();
  TextColumn get providerStatus => text()();
  TextColumn get labelsJson => text().withDefault(const Constant('[]'))();
  TextColumn get assignee => text().nullable()();
  TextColumn get url => text().nullable()();
  IntColumn get severity => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get providerEntityJson => text().nullable()();
  TextColumn get sourceHash => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CommentRow')
class Comments extends Table {
  TextColumn get id => text()();
  TextColumn get ticketId => text()();
  TextColumn get authorName => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get origin => text().withDefault(const Constant('provider'))();
  BoolColumn get synced => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row (`id = 0`) app appearance + language preferences.
@DataClassName('SettingRow')
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get variant => text().withDefault(const Constant('light'))();
  TextColumn get surface => text().withDefault(const Constant('outline'))();
  TextColumn get density => text().withDefault(const Constant('comfortable'))();
  TextColumn get detailLayout =>
      text().withDefault(const Constant('twoPane'))();
  TextColumn get dateFormat => text().withDefault(const Constant('iso'))();
  BoolColumn get companyTint => boolean().withDefault(const Constant(false))();
  TextColumn get localeCode => text().withDefault(const Constant('en'))();
  TextColumn get fontFamily =>
      text().withDefault(const Constant('Space Grotesk'))();
  RealColumn get componentRadius => real().withDefault(const Constant(8.0))();
  IntColumn get accentColorValue => integer().nullable()();

  /// JSON array of pinned ZenTao project keys (`"accountId:productId"`), shown at
  /// the top of the sources tree. Persisted so pins survive restarts.
  TextColumn get pinnedProjectsJson =>
      text().withDefault(const Constant('[]'))();

  /// JSON array of pinned ZenTao executions (`{accountId, projectId,
  /// executionId, name}`), shown alongside pinned projects. Persisted so pins
  /// survive restarts.
  TextColumn get pinnedExecutionsJson =>
      text().withDefault(const Constant('[]'))();

  /// Width (logical px) of the left sidebar, adjustable by dragging its right
  /// edge. Persisted so the chosen width survives restarts.
  RealColumn get sidebarWidth => real().withDefault(const Constant(290.0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ActivityRow')
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get ticketId => text()();
  TextColumn get actor => text()();
  TextColumn get action => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get detail => text().nullable()();
  TextColumn get attachmentsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TranslationRow')
class Translations extends Table {
  TextColumn get ticketId => text()();
  TextColumn get sourceHash => text()();
  TextColumn get targetLang => text()();
  TextColumn get translatedTitle => text()();
  TextColumn get translatedBody => text()();
  TextColumn get model => text()();
  TextColumn get templateVersion => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ticketId};
}

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'worknexus'));

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // from < 2: create the settings table at its *current* schema (which
      // already includes fontFamily), so skip the addColumn below.
      if (from < 2) {
        await m.createTable(settings);
      } else if (from < 3) {
        await m.addColumn(settings, settings.fontFamily);
      }
      if (from < 4) await m.createTable(activities);
      if (from < 5) await m.addColumn(tickets, tickets.providerEntityJson);
      if (from < 6) await m.addColumn(activities, activities.attachmentsJson);
      if (from < 7) await m.addColumn(settings, settings.componentRadius);
      if (from < 8) await m.addColumn(settings, settings.accentColorValue);
      if (from < 9) await m.addColumn(settings, settings.pinnedProjectsJson);
      if (from < 10) await m.addColumn(settings, settings.detailLayout);
      if (from < 11) await m.addColumn(settings, settings.dateFormat);
      if (from < 12) {
        await m.addColumn(settings, settings.pinnedExecutionsJson);
      }
      if (from < 13) await m.addColumn(settings, settings.sidebarWidth);
    },
  );

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

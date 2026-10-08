import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'database_location.dart';

part 'database.g.dart';

@DataClassName('WorkspaceRow')
class Workspaces extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get shortCode => text()();
  IntColumn get colorValue => integer()();
  TextColumn get iconKey => text().withDefault(const Constant('briefcase'))();
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

  /// Target language tickets are machine-translated into (BCP-47 code). Distinct
  /// from [localeCode] (the app UI language). Defaults to Vietnamese.
  TextColumn get translationLang => text().withDefault(const Constant('vi'))();

  /// The `provider/model` OpenCode translates with. Empty = OpenCode's own
  /// default model.
  TextColumn get translationModel => text().withDefault(const Constant(''))();
  TextColumn get fontFamily =>
      text().withDefault(const Constant('Space Grotesk'))();
  RealColumn get componentRadius => real().withDefault(const Constant(8.0))();

  /// Chat message layout style (`ChatAppearance` name).
  TextColumn get chatAppearance =>
      text().withDefault(const Constant('worknexus'))();

  /// Whether chat messages are sent as Markdown.
  BoolColumn get chatSendMarkdown =>
      boolean().withDefault(const Constant(false))();
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

/// A user-named filter preset (the board's "Save filter"). [filterJson] is the
/// serialized `FilterState`; see the board feature's saved-filter mapper.
@DataClassName('SavedFilterRow')
class SavedFilters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get filterJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-account ZenTao chat settings: an optional xxd address override, the
/// pinned (trusted) certificate fingerprint, and the account's chat user id.
@DataClassName('ChatAccountRow')
class ChatAccounts extends Table {
  TextColumn get accountId => text()();
  TextColumn get serverUrl => text().nullable()();
  TextColumn get pinnedFingerprint => text().nullable()();
  IntColumn get userId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {accountId};
}

/// A ZenTao chat conversation. Unread = [lastMessageIndex] − [lastReadIndex]
/// (xxd's per-chat message indexes).
@DataClassName('ChatConversationRow')
class ChatConversations extends Table {
  TextColumn get accountId => text()();
  TextColumn get gid => text()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  DateTimeColumn get lastActiveAt => dateTime().nullable()();
  IntColumn get lastMessageId => integer().nullable()();
  IntColumn get lastMessageIndex => integer().withDefault(const Constant(0))();
  IntColumn get lastReadIndex => integer().withDefault(const Constant(0))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {accountId, gid};
}

/// A ZenTao chat message. [gid] is the client-generated id; [serverId] is set
/// once xxd stores it. [sendState] is `sent`, `pending` or `failed`.
@DataClassName('ChatMessageRow')
@TableIndex(
  name: 'chat_messages_by_chat',
  columns: {#accountId, #cgid, #sentAt},
)
class ChatMessages extends Table {
  TextColumn get accountId => text()();
  TextColumn get gid => text()();
  TextColumn get cgid => text()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get messageIndex => integer().nullable()();
  IntColumn get senderId => integer()();
  DateTimeColumn get sentAt => dateTime()();
  TextColumn get contentType => text()();
  TextColumn get content => text()();
  TextColumn get sendState => text().withDefault(const Constant('sent'))();

  /// Server id of the message this one replies to (`data.replyTo`).
  IntColumn get replyToId => integer().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {accountId, gid};
}

/// A ZenTao user as seen by chat (names and avatars for senders and peers).
@DataClassName('ChatUserRow')
class ChatUsers extends Table {
  TextColumn get accountId => text()();
  IntColumn get userId => integer()();
  TextColumn get account => text()();
  TextColumn get realname => text()();
  TextColumn get avatar => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {accountId, userId};
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
    SavedFilters,
    ChatAccounts,
    ChatConversations,
    ChatMessages,
    ChatUsers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  static QueryExecutor _openDefault() => driftDatabase(
    name: kDatabaseName,
    native: const DriftNativeOptions(
      databaseDirectory: resolveDatabaseDirectory,
    ),
  );

  @override
  int get schemaVersion => 19;

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
      if (from < 13) {
        // Idempotent: a dev DB may already carry the column from a half-applied
        // migration (added, but the schema version not yet bumped). Skip then.
        if (!await _hasColumn('settings', 'sidebar_width')) {
          await m.addColumn(settings, settings.sidebarWidth);
        }
      }
      if (from < 14) {
        if (!await _hasColumn('settings', 'translation_lang')) {
          await m.addColumn(settings, settings.translationLang);
        }
      }
      if (from < 15) {
        if (!await _hasColumn('workspaces', 'icon_key')) {
          await m.addColumn(workspaces, workspaces.iconKey);
        }
      }
      if (from < 16) {
        if (!await _hasColumn('settings', 'translation_model')) {
          await m.addColumn(settings, settings.translationModel);
        }
        await m.createTable(savedFilters);
      }
      if (from < 17) {
        await m.createTable(chatAccounts);
        await m.createTable(chatConversations);
        await m.createTable(chatMessages);
        await m.createIndex(chatMessagesByChat);
        await m.createTable(chatUsers);
      }
      if (from < 18) {
        if (!await _hasColumn('chat_messages', 'reply_to_id')) {
          await m.addColumn(chatMessages, chatMessages.replyToId);
        }
      }
      if (from < 19) {
        if (!await _hasColumn('settings', 'chat_appearance')) {
          await m.addColumn(settings, settings.chatAppearance);
        }
        if (!await _hasColumn('settings', 'chat_send_markdown')) {
          await m.addColumn(settings, settings.chatSendMarkdown);
        }
      }
    },
  );

  /// Whether [table] already has [column]. Used to keep column-add migrations
  /// idempotent when a dev DB carries a column from a half-applied migration
  /// (added, but the schema version not yet bumped).
  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect(
      'SELECT 1 FROM pragma_table_info(?) WHERE name = ?',
      variables: [Variable<String>(table), Variable<String>(column)],
    ).get();
    return rows.isNotEmpty;
  }

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

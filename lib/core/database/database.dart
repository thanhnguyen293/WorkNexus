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

  /// Whether the theme follows the OS light/dark mode instead of [variant].
  BoolColumn get themeFollowsSystem =>
      boolean().withDefault(const Constant(false))();
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

  /// Whether own bubbles in the messenger-like chat styles use the app's
  /// accent colour instead of the messenger's own.
  BoolColumn get chatPrimaryBubbles =>
      boolean().withDefault(const Constant(false))();

  /// Chat wallpaper: '' = the style's own, 'none' = plain colour, otherwise
  /// the path of an image the user picked.
  TextColumn get chatWallpaper =>
      text().withDefault(const Constant('pattern'))();

  /// How much the wallpaper image is darkened (0–1), for readability.
  RealColumn get chatWallpaperDim => real().withDefault(const Constant(0.2))();

  /// Whether chat messages are sent as Markdown.
  BoolColumn get chatSendMarkdown =>
      boolean().withDefault(const Constant(false))();

  /// Whether new chat messages raise a desktop notification.
  BoolColumn get chatNotifications =>
      boolean().withDefault(const Constant(true))();

  /// Whether to notify even for the chat open in the focused window.
  BoolColumn get chatNotifyWhileViewing =>
      boolean().withDefault(const Constant(true))();

  /// Most disk space chat attachments may use, in MB.
  IntColumn get chatCacheLimitMb =>
      integer().withDefault(const Constant(2048))();

  /// Whether chat videos up to [chatAutoDownloadVideoMb] download on their
  /// own (for their preview frame and instant playback).
  BoolColumn get chatAutoDownloadVideos =>
      boolean().withDefault(const Constant(true))();

  /// How much the chat's text is scaled (1.0: as designed).
  RealColumn get chatTextScale => real().withDefault(const Constant(1.0))();
  IntColumn get chatAutoDownloadVideoMb =>
      integer().withDefault(const Constant(20))();
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

  /// Server ids of pinned messages, as a JSON array.
  TextColumn get pinnedJson => text().withDefault(const Constant('[]'))();

  /// The group's avatar as xxd sends it (`{type, data}`), JSON; null =
  /// none (initials are drawn).
  TextColumn get avatarJson => text().nullable()();

  /// Pinned to the top of the chat list (xxd `star`).
  BoolColumn get starred => boolean().withDefault(const Constant(false))();

  /// Notifications silenced for this chat. Local only: xxd has no mute.
  BoolColumn get muted => boolean().withDefault(const Constant(false))();

  /// User ids of the group's admins, as a JSON array.
  TextColumn get adminsJson => text().withDefault(const Constant('[]'))();

  /// Who may send (xxd `committers`): empty/`$ALL` everyone, `$ADMINS` the
  /// owner and admins, else a comma list of user ids or accounts.
  TextColumn get committers => text().withDefault(const Constant(''))();

  /// Account of the group's owner, and when the chat was created.
  TextColumn get ownedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

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

  /// Stored on its own — a reply's parent, a pinned message, a page around
  /// a jump target — not as part of the run of history that reaches the
  /// newest message. The timeline skips these until a page joins them up,
  /// so a lone old message never sits on top of the latest ones as if
  /// nothing came between.
  BoolColumn get detached => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {accountId, gid};
}

/// A machine translation of a chat message, one per target language, so a
/// message is translated once and then read from here.
@DataClassName('ChatMessageTranslationRow')
class ChatMessageTranslations extends Table {
  TextColumn get accountId => text()();
  TextColumn get gid => text()();
  TextColumn get targetLang => text()();
  TextColumn get translatedText => text()();

  /// The model that produced it; empty = OpenCode's own default.
  TextColumn get model => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Whether the translation is shown under the message; hiding keeps it, so
  /// showing it again costs nothing.
  BoolColumn get visible => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {accountId, gid, targetLang};
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

  /// Profile details shown in the chat info panel.
  TextColumn get email => text().nullable()();
  TextColumn get mobile => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get role => text().nullable()();

  /// Presence: `online`, `away`, `busy`, `offline`… (null = unknown).
  TextColumn get status => text().nullable()();

  @override
  Set<Column> get primaryKey => {accountId, userId};
}

@DataClassName('ZenTaoProfileRow')
class ZenTaoProfiles extends Table {
  TextColumn get accountId => text()();
  TextColumn get profileJson => text()();

  @override
  Set<Column> get primaryKey => {accountId};
}

/// The last ZenTao dashboard reply (`GET /user?fields=…`) per account, stored
/// raw so the dashboard opens instantly and offline; parsed on read.
@DataClassName('DashboardSnapshotRow')
class DashboardSnapshots extends Table {
  TextColumn get accountId => text()();
  TextColumn get json => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId};
}

/// The last provider container list (ZenTao products / projects, GitLab
/// projects, GitHub repos) per account and [kind], stored raw so the sidebar
/// tree — and the pins resolved against it — renders instantly on launch
/// instead of waiting for the network; parsed on read.
@DataClassName('SourceListSnapshotRow')
class SourceListSnapshots extends Table {
  TextColumn get accountId => text()();
  TextColumn get kind => text()();
  TextColumn get json => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, kind};
}

/// ZenTao web notifications (the bell menu), per account. The server's list
/// replaces an account's rows on every refresh.
@DataClassName('ZenTaoNotificationRow')
class ZenTaoNotifications extends Table {
  TextColumn get accountId => text()();
  TextColumn get id => text()();
  TextColumn get summary => text()();
  TextColumn get objectType => text().nullable()();
  TextColumn get objectId => text().nullable()();
  TextColumn get objectTitle => text().nullable()();
  TextColumn get url => text().nullable()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

/// Link previews (OpenGraph / oEmbed) for URLs shared in chat, so a card
/// shows at once after a restart instead of refetching the page. [empty]
/// records a page with nothing to show; failures are never stored.
@DataClassName('ChatLinkPreviewRow')
class ChatLinkPreviews extends Table {
  TextColumn get url => text()();
  BoolColumn get empty => boolean().withDefault(const Constant(false))();

  /// Where the link landed after redirects (the preview's own URL).
  TextColumn get pageUrl => text().nullable()();
  TextColumn get siteName => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {url};
}

/// Where the user last saved a copy of a chat attachment ("Save as…"), so
/// "Show in folder" opens that copy rather than the app's cache.
@DataClassName('ChatSavedFileRow')
class ChatSavedFiles extends Table {
  TextColumn get accountId => text()();
  IntColumn get fileId => integer()();
  TextColumn get path => text()();
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, fileId};
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
    ZenTaoProfiles,
    ChatMessageTranslations,
    DashboardSnapshots,
    ZenTaoNotifications,
    SourceListSnapshots,
    ChatLinkPreviews,
    ChatSavedFiles,
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
  int get schemaVersion => 43;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 33) await m.createTable(zenTaoProfiles);
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
        // Tables use IF NOT EXISTS; the index does not. Guarded because the
        // same DB file can be reopened after an older build has lowered its
        // version (e.g. running another branch), re-running this step.
        if (!await _hasIndex('chat_messages_by_chat')) {
          await m.createIndex(chatMessagesByChat);
        }
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
      if (from < 20) {
        if (!await _hasColumn('settings', 'chat_notifications')) {
          await m.addColumn(settings, settings.chatNotifications);
        }
      }
      if (from < 21) {
        for (final (column, add) in [
          ('pinned_json', chatConversations.pinnedJson),
          ('owned_by', chatConversations.ownedBy),
          ('created_at', chatConversations.createdAt),
        ]) {
          if (!await _hasColumn('chat_conversations', column)) {
            await m.addColumn(chatConversations, add);
          }
        }
        for (final (column, add) in [
          ('email', chatUsers.email),
          ('mobile', chatUsers.mobile),
          ('phone', chatUsers.phone),
          ('role', chatUsers.role),
        ]) {
          if (!await _hasColumn('chat_users', column)) {
            await m.addColumn(chatUsers, add);
          }
        }
      }
      if (from < 35) {
        if (!await _hasColumn('settings', 'chat_text_scale')) {
          await m.addColumn(settings, settings.chatTextScale);
        }
      }
      if (from < 34) {
        if (!await _hasColumn('chat_conversations', 'committers')) {
          await m.addColumn(chatConversations, chatConversations.committers);
        }
      }
      if (from < 33) {
        if (!await _hasColumn('settings', 'chat_notify_while_viewing')) {
          await m.addColumn(settings, settings.chatNotifyWhileViewing);
        }
      }
      if (from < 32) {
        if (!await _hasColumn('settings', 'chat_auto_download_videos')) {
          await m.addColumn(settings, settings.chatAutoDownloadVideos);
        }
        if (!await _hasColumn('settings', 'chat_auto_download_video_mb')) {
          await m.addColumn(settings, settings.chatAutoDownloadVideoMb);
        }
      }
      if (from < 31) {
        await m.createTable(chatMessageTranslations);
        // Dev DBs already at 30 have the table without this column.
        if (!await _hasColumn('chat_message_translations', 'visible')) {
          await m.addColumn(
            chatMessageTranslations,
            chatMessageTranslations.visible,
          );
        }
      }
      if (from < 29) {
        if (!await _hasColumn('chat_conversations', 'muted')) {
          await m.addColumn(chatConversations, chatConversations.muted);
        }
      }
      if (from < 28) {
        if (!await _hasColumn('chat_conversations', 'starred')) {
          await m.addColumn(chatConversations, chatConversations.starred);
        }
      }
      if (from < 27) {
        if (!await _hasColumn('settings', 'chat_wallpaper')) {
          await m.addColumn(settings, settings.chatWallpaper);
        }
        if (!await _hasColumn('settings', 'chat_wallpaper_dim')) {
          await m.addColumn(settings, settings.chatWallpaperDim);
        }
      }
      if (from < 26) {
        if (!await _hasColumn('settings', 'chat_primary_bubbles')) {
          await m.addColumn(settings, settings.chatPrimaryBubbles);
        }
      }
      if (from < 25) {
        if (!await _hasColumn('chat_conversations', 'avatar_json')) {
          await m.addColumn(chatConversations, chatConversations.avatarJson);
        }
        if (!await _hasColumn('chat_users', 'status')) {
          await m.addColumn(chatUsers, chatUsers.status);
        }
      }
      if (from < 24) {
        // Zalo became the default chat style; installs still on the old
        // default follow it (the style menu changes it any time).
        await customStatement(
          "UPDATE settings SET chat_appearance = 'zalo' "
          "WHERE chat_appearance = 'worknexus'",
        );
      }
      if (from < 23) {
        if (!await _hasColumn('settings', 'chat_cache_limit_mb')) {
          await m.addColumn(settings, settings.chatCacheLimitMb);
        }
      }
      if (from < 22) {
        if (!await _hasColumn('chat_conversations', 'admins_json')) {
          await m.addColumn(chatConversations, chatConversations.adminsJson);
        }
      }
      // Versions 32–37 were used on parallel branches (36 twice: ZenTao
      // profiles on one, the dashboard on another). After a rebase, a DB can
      // report the latest version while still missing another branch's tables
      // or columns. Reconcile them once before any row is read.
      if (from < 43) {
        if (!await _hasTable('chat_saved_files')) {
          await m.createTable(chatSavedFiles);
        }
      }
      if (from < 42) {
        if (!await _hasTable('chat_link_previews')) {
          await m.createTable(chatLinkPreviews);
        }
      }
      if (from < 41) {
        if (!await _hasTable('source_list_snapshots')) {
          await m.createTable(sourceListSnapshots);
        }
      }
      if (from < 40) {
        if (!await _hasColumn('chat_messages', 'detached')) {
          await m.addColumn(chatMessages, chatMessages.detached);
        }
        await _detachBeyondFirstGap();
      }
      if (from < 39) {
        if (!await _hasColumn('settings', 'theme_follows_system')) {
          await m.addColumn(settings, settings.themeFollowsSystem);
        }
      }
      if (from < 38) {
        for (final (name, table) in <(String, TableInfo<Table, Object?>)>[
          ('zen_tao_profiles', zenTaoProfiles),
          ('dashboard_snapshots', dashboardSnapshots),
          ('zen_tao_notifications', zenTaoNotifications),
        ]) {
          if (!await _hasTable(name)) await m.createTable(table);
        }
        for (final (name, column) in [
          ('chat_auto_download_videos', settings.chatAutoDownloadVideos),
          ('chat_auto_download_video_mb', settings.chatAutoDownloadVideoMb),
          ('chat_notify_while_viewing', settings.chatNotifyWhileViewing),
          ('chat_text_scale', settings.chatTextScale),
        ]) {
          if (!await _hasColumn('settings', name)) {
            await m.addColumn(settings, column);
          }
        }
        if (!await _hasColumn('chat_conversations', 'committers')) {
          await m.addColumn(chatConversations, chatConversations.committers);
        }
        // An older branch may have created this column as nullable.
        await customStatement(
          'UPDATE settings SET chat_notify_while_viewing = 1 '
          'WHERE chat_notify_while_viewing IS NULL',
        );
      }
    },
  );

  /// Whether [table] already has [column]. Used to keep column-add migrations
  /// idempotent when a dev DB carries a column from a half-applied migration
  /// (added, but the schema version not yet bumped).
  Future<bool> _hasIndex(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ?",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _hasTable(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Marks, per chat, the stored messages past the first break in their
  /// indexes (walking back from the newest) as detached: history stored
  /// before that flag existed may already hold lone reply parents.
  Future<void> _detachBeyondFirstGap() async {
    final rows = await customSelect(
      'SELECT account_id, cgid, message_index FROM chat_messages '
      'WHERE message_index IS NOT NULL '
      'ORDER BY account_id, cgid, message_index DESC',
    ).get();
    String? chat;
    int? previous;
    final cuts = <(String, String, int)>[];
    var cutDone = false;
    for (final row in rows) {
      final accountId = row.read<String>('account_id');
      final cgid = row.read<String>('cgid');
      final index = row.read<int>('message_index');
      final key = '$accountId\u0000$cgid';
      if (key != chat) {
        chat = key;
        previous = null;
        cutDone = false;
      }
      if (cutDone) continue;
      if (previous != null && index < previous - 1) {
        cuts.add((accountId, cgid, index));
        cutDone = true;
      }
      previous = index;
    }
    for (final (accountId, cgid, below) in cuts) {
      await customStatement(
        'UPDATE chat_messages SET detached = 1 '
        'WHERE account_id = ? AND cgid = ? AND message_index <= ?',
        [accountId, cgid, below],
      );
    }
  }

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

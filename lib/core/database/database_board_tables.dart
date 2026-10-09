part of 'database.dart';

// Board tables: workspaces, accounts (and their ZenTao profiles), projects, tickets and their satellites.

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
      boolean().withDefault(const Constant(false))();

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

@DataClassName('ZenTaoProfileRow')
class ZenTaoProfiles extends Table {
  TextColumn get accountId => text()();
  TextColumn get profileJson => text()();

  @override
  Set<Column> get primaryKey => {accountId};
}

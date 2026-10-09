part of 'database.dart';

// ZenTao chat tables.

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

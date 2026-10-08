import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../domain/entities/chat_message.dart';

/// Drift access for chat (CLAUDE.md 3.4: SQL stays in `datasources/`).
class ChatLocalDatasource {
  ChatLocalDatasource(this._db);

  final AppDatabase _db;

  // ---- accounts --------------------------------------------------------------

  Future<AccountRow?> account(String accountId) => (_db.select(
    _db.accounts,
  )..where((a) => a.id.equals(accountId))).getSingleOrNull();

  Future<ChatAccountRow?> chatAccount(String accountId) => (_db.select(
    _db.chatAccounts,
  )..where((c) => c.accountId.equals(accountId))).getSingleOrNull();

  Future<void> saveChatAccount(ChatAccountsCompanion row) =>
      _db.into(_db.chatAccounts).insertOnConflictUpdate(row);

  // ---- conversations ---------------------------------------------------------

  Future<void> upsertConversations(List<ChatConversationsCompanion> rows) => _db
      .batch((b) => b.insertAllOnConflictUpdate(_db.chatConversations, rows));

  /// Conversations and their last messages in one transaction, so watchers
  /// never see a chat without its preview.
  Future<void> upsertConversationsWithMessages(
    List<ChatConversationsCompanion> conversations,
    List<ChatMessagesCompanion> messages,
  ) => _db.transaction(() async {
    await upsertConversations(conversations);
    await upsertMessages(messages);
  });

  Future<ChatConversationRow?> conversation(String accountId, String gid) =>
      (_db.select(_db.chatConversations)
            ..where((c) => c.accountId.equals(accountId) & c.gid.equals(gid)))
          .getSingleOrNull();

  /// Moves the conversation's "last message" forward to a newly arrived
  /// message; a message the account sent itself also marks the chat read.
  Future<void> recordMessage(
    String accountId,
    String cgid, {
    required int? serverId,
    required int? index,
    required DateTime sentAt,
    required bool fromSelf,
  }) async {
    final row = await conversation(accountId, cgid);
    if (row == null) return;
    final newer = serverId != null && serverId > (row.lastMessageId ?? 0);
    final newIndex = index != null && index > row.lastMessageIndex
        ? index
        : row.lastMessageIndex;
    await (_db.update(
      _db.chatConversations,
    )..where((c) => c.accountId.equals(accountId) & c.gid.equals(cgid))).write(
      ChatConversationsCompanion(
        lastMessageId: newer ? Value(serverId) : const Value.absent(),
        lastMessageIndex: Value(newIndex),
        lastReadIndex: fromSelf && index != null
            ? Value(newIndex)
            : const Value.absent(),
        lastActiveAt: newer ? Value(sentAt) : const Value.absent(),
      ),
    );
  }

  /// Brings a chat up the list for a message without a server id (a
  /// notification); never moves it back.
  Future<void> touchConversation(String accountId, String gid, DateTime at) =>
      (_db.update(_db.chatConversations)..where(
            (c) =>
                c.accountId.equals(accountId) &
                c.gid.equals(gid) &
                (c.lastActiveAt.isNull() |
                    c.lastActiveAt.isSmallerThanValue(at)),
          ))
          .write(ChatConversationsCompanion(lastActiveAt: Value(at)));

  /// Moves the read marker forward (never back: a late echo from another
  /// device must not resurrect unread messages).
  Future<void> setLastReadIndex(String accountId, String gid, int index) =>
      (_db.update(_db.chatConversations)..where(
            (c) =>
                c.accountId.equals(accountId) &
                c.gid.equals(gid) &
                c.lastReadIndex.isSmallerThanValue(index),
          ))
          .write(ChatConversationsCompanion(lastReadIndex: Value(index)));

  /// Ids of the accounts that have logged into chat.
  Future<List<String>> chatAccountIds() async => [
    for (final row in await _db.select(_db.chatAccounts).get()) row.accountId,
  ];

  /// Chat, content type and content of every image/file message.
  Future<List<({String cgid, String contentType, String content})>>
  attachmentMessages(String accountId) async {
    final rows =
        await (_db.select(_db.chatMessages)..where(
              (m) =>
                  m.accountId.equals(accountId) &
                  m.contentType.isIn(const ['image', 'file']),
            ))
            .get();
    return [
      for (final r in rows)
        (cgid: r.cgid, contentType: r.contentType, content: r.content),
    ];
  }

  /// Sets a user's presence (`online`, `offline`…).
  Future<void> setUserStatus(String accountId, int userId, String status) =>
      (_db.update(_db.chatUsers)..where(
            (u) => u.accountId.equals(accountId) & u.userId.equals(userId),
          ))
          .write(ChatUsersCompanion(status: Value(status)));

  /// Sets a chat's avatar (xxd JSON).
  Future<void> setChatAvatar(String accountId, String gid, String json) =>
      (_db.update(_db.chatConversations)
            ..where((c) => c.accountId.equals(accountId) & c.gid.equals(gid)))
          .write(ChatConversationsCompanion(avatarJson: Value(json)));

  /// Replaces a chat's pinned message ids ([pinnedJson] is a JSON array).
  Future<void> setPinned(String accountId, String gid, String pinnedJson) =>
      (_db.update(_db.chatConversations)
            ..where((c) => c.accountId.equals(accountId) & c.gid.equals(gid)))
          .write(ChatConversationsCompanion(pinnedJson: Value(pinnedJson)));

  /// Pins or unpins a chat at the top of the list.
  Future<void> setStarred(
    String accountId,
    String gid, {
    required bool starred,
  }) =>
      (_db.update(_db.chatConversations)
            ..where((c) => c.accountId.equals(accountId) & c.gid.equals(gid)))
          .write(ChatConversationsCompanion(starred: Value(starred)));

  /// Conversations with their last message: pinned ones first, then the
  /// most recently active.
  Stream<List<(ChatConversationRow, ChatMessageRow?)>> watchConversations(
    String accountId,
  ) {
    final c = _db.chatConversations;
    final m = _db.chatMessages;
    final query =
        _db.select(c).join([
            leftOuterJoin(
              m,
              m.accountId.equalsExp(c.accountId) &
                  m.cgid.equalsExp(c.gid) &
                  m.serverId.equalsExp(c.lastMessageId),
            ),
          ])
          ..where(c.accountId.equals(accountId))
          ..orderBy([
            OrderingTerm.desc(c.starred),
            OrderingTerm.desc(c.lastActiveAt),
          ]);
    return query.watch().map(
      (rows) => [for (final r in rows) (r.readTable(c), r.readTableOrNull(m))],
    );
  }

  // ---- messages --------------------------------------------------------------

  Future<void> upsertMessages(List<ChatMessagesCompanion> rows) =>
      _db.batch((b) => b.insertAllOnConflictUpdate(_db.chatMessages, rows));

  Future<void> insertMessage(ChatMessagesCompanion row) =>
      _db.into(_db.chatMessages).insert(row);

  Future<ChatMessageRow?> message(String accountId, String gid) =>
      (_db.select(_db.chatMessages)
            ..where((m) => m.accountId.equals(accountId) & m.gid.equals(gid)))
          .getSingleOrNull();

  Future<void> setSendState(String accountId, String gid, SendState state) =>
      (_db.update(_db.chatMessages)
            ..where((m) => m.accountId.equals(accountId) & m.gid.equals(gid)))
          .write(ChatMessagesCompanion(sendState: Value(state.name)));

  /// Replaces a pending message's content (e.g. once its upload finished).
  Future<void> setContent(
    String accountId,
    String gid, {
    required String contentType,
    required String content,
  }) =>
      (_db.update(
        _db.chatMessages,
      )..where((m) => m.accountId.equals(accountId) & m.gid.equals(gid))).write(
        ChatMessagesCompanion(
          contentType: Value(contentType),
          content: Value(content),
        ),
      );

  /// Marks messages still `pending` from before [before] as failed — they were
  /// interrupted (e.g. the app quit mid-send).
  Future<int> failStalePending(String accountId, DateTime before) =>
      (_db.update(_db.chatMessages)..where(
            (m) =>
                m.accountId.equals(accountId) &
                m.sendState.equals(SendState.pending.name) &
                m.sentAt.isSmallerThanValue(before),
          ))
          .write(
            ChatMessagesCompanion(sendState: Value(SendState.failed.name)),
          );

  Future<int?> oldestServerId(String accountId, String cgid) async {
    final m = _db.chatMessages;
    final min = m.serverId.min();
    final row =
        await (_db.selectOnly(m)
              ..addColumns([min])
              ..where(m.accountId.equals(accountId) & m.cgid.equals(cgid)))
            .getSingle();
    return row.read(min);
  }

  /// How many stored messages of a chat were sent before [before].
  Future<int> countOlder(String accountId, String cgid, DateTime before) async {
    final m = _db.chatMessages;
    final count = m.gid.count();
    final row =
        await (_db.selectOnly(m)
              ..addColumns([count])
              ..where(
                m.accountId.equals(accountId) &
                    m.cgid.equals(cgid) &
                    m.sentAt.isSmallerThanValue(before),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// The newest [limit] messages of a chat, oldest first.
  Stream<List<ChatMessageRow>> watchMessages(
    String accountId,
    String cgid, {
    required int limit,
  }) {
    final query = _db.select(_db.chatMessages)
      ..where((m) => m.accountId.equals(accountId) & m.cgid.equals(cgid))
      ..orderBy([(m) => OrderingTerm.desc(m.sentAt)])
      ..limit(limit);
    return query.watch().map((rows) => rows.reversed.toList());
  }

  /// One message by its server id (null until it is stored locally).
  Stream<ChatMessageRow?> watchMessageByServerId(
    String accountId,
    String cgid,
    int serverId,
  ) =>
      (_db.select(_db.chatMessages)..where(
            (m) =>
                m.accountId.equals(accountId) &
                m.cgid.equals(cgid) &
                m.serverId.equals(serverId),
          ))
          .watch()
          .map((rows) => rows.firstOrNull);

  /// Every reply stored for a chat, oldest first (threads are built from it).
  Stream<List<ChatMessageRow>> watchReplies(String accountId, String cgid) =>
      (_db.select(_db.chatMessages)
            ..where(
              (m) =>
                  m.accountId.equals(accountId) &
                  m.cgid.equals(cgid) &
                  m.replyToId.isNotNull(),
            )
            ..orderBy([(m) => OrderingTerm.asc(m.sentAt)]))
          .watch();

  /// A chat's image and file messages (not retracted), newest first.
  Stream<List<ChatMessageRow>> watchAttachments(
    String accountId,
    String cgid,
  ) =>
      (_db.select(_db.chatMessages)
            ..where(
              (m) =>
                  m.accountId.equals(accountId) &
                  m.cgid.equals(cgid) &
                  m.contentType.isIn(const ['image', 'file']) &
                  m.deleted.equals(false),
            )
            ..orderBy([(m) => OrderingTerm.desc(m.sentAt)]))
          .watch();

  // ---- users -----------------------------------------------------------------

  Future<void> upsertUsers(List<ChatUsersCompanion> rows) =>
      _db.batch((b) => b.insertAllOnConflictUpdate(_db.chatUsers, rows));

  Future<Set<int>> knownUserIds(String accountId) async {
    final rows = await (_db.select(
      _db.chatUsers,
    )..where((u) => u.accountId.equals(accountId))).get();
    return {for (final r in rows) r.userId};
  }

  Stream<List<ChatUserRow>> watchUsers(String accountId) => (_db.select(
    _db.chatUsers,
  )..where((u) => u.accountId.equals(accountId))).watch();

  Stream<int?> watchSelfUserId(String accountId) =>
      (_db.select(_db.chatAccounts)
            ..where((c) => c.accountId.equals(accountId)))
          .watchSingleOrNull()
          .map((row) => row?.userId);
}

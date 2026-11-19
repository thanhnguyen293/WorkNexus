import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';

/// Drift writes to a chat's group state — name, picture, settings, admins,
/// category and archiving — as the server reports changes to it.
class ChatGroupLocalDatasource {
  ChatGroupLocalDatasource(this._db);

  final AppDatabase _db;

  /// Sets a chat's avatar (xxd JSON).
  Future<void> setChatAvatar(String accountId, String gid, String json) =>
      (_db.update(_db.chatConversations)
            ..where((c) => c.accountId.equals(accountId) & c.gid.equals(gid)))
          .write(ChatConversationsCompanion(avatarJson: Value(json)));

  /// Renames a chat.
  Future<void> setChatName(String accountId, String gid, String name) =>
      (_db.update(_db.chatConversations)
            ..where((c) => c.accountId.equals(accountId) & c.gid.equals(gid)))
          .write(ChatConversationsCompanion(name: Value(name)));

  /// Archives a chat (or a dismissed group), taking it off the chat list.
  Future<void> setArchived(
    String accountId,
    String gid, {
    required bool archived,
  }) =>
      (_db.update(_db.chatConversations)
            ..where((c) => c.accountId.equals(accountId) & c.gid.equals(gid)))
          .write(ChatConversationsCompanion(archived: Value(archived)));

  /// Updates a group's settings; a null one is left as it is.
  Future<void> setGroupSettings(
    String accountId,
    String gid, {
    String? committers,
    bool? isPublic,
    bool? adminInvite,
  }) =>
      (_db.update(
        _db.chatConversations,
      )..where((c) => c.accountId.equals(accountId) & c.gid.equals(gid))).write(
        ChatConversationsCompanion(
          committers: Value.absentIfNull(committers),
          isPublic: Value.absentIfNull(isPublic),
          adminInvite: Value.absentIfNull(adminInvite),
        ),
      );

  /// Files chats [gids] under [category] ('' for none).
  Future<void> setCategory(
    String accountId,
    List<String> gids,
    String category,
  ) =>
      (_db.update(_db.chatConversations)
            ..where((c) => c.accountId.equals(accountId) & c.gid.isIn(gids)))
          .write(ChatConversationsCompanion(category: Value(category)));

  /// Replaces a group's admin ids ([adminsJson] is a JSON array).
  Future<void> setAdmins(String accountId, String gid, String adminsJson) =>
      (_db.update(_db.chatConversations)
            ..where((c) => c.accountId.equals(accountId) & c.gid.equals(gid)))
          .write(ChatConversationsCompanion(adminsJson: Value(adminsJson)));
}

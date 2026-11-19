import '../../../../core/error/result.dart';

/// Managing group chats (name, members, admins, owner, settings) and filing
/// chats under the user's categories. Kept apart from `ChatRepository`'s
/// reading and messaging so each interface stays one job.
abstract interface class ChatGroupRepository {
  /// Files chats [chatGids] under [category] ('' for none).
  Future<Result<void>> setChatCategory(
    String accountId,
    List<String> chatGids,
    String category,
  );

  /// Sets group [chatGid]'s settings: [isPublic], [adminInvite] (only the
  /// owner and admins add people) and [committers] (who may post, as xxd
  /// stores it).
  Future<Result<void>> setGroupSettings(
    String accountId,
    String chatGid, {
    required bool isPublic,
    required bool adminInvite,
    required String committers,
  });

  /// Makes [userIds] admins of group [chatGid] ([admin]) or plain members.
  Future<Result<void>> setGroupAdmins(
    String accountId,
    String chatGid,
    List<int> userIds, {
    required bool admin,
  });

  /// Hands group [chatGid] over to [userId], its new owner.
  Future<Result<void>> transferGroupOwnership(
    String accountId,
    String chatGid,
    int userId,
  );

  /// Renames group [chatGid] to [name] for every member.
  Future<Result<void>> renameGroupChat(
    String accountId,
    String chatGid,
    String name,
  );

  /// Dismisses (disbands) group [chatGid] for every member; only its owner
  /// may.
  Future<Result<void>> dismissGroupChat(String accountId, String chatGid);

  /// Leaves group [chatGid] (its owner dismisses it instead).
  Future<Result<void>> leaveGroupChat(String accountId, String chatGid);

  /// Adds [userIds] to group [chatGid].
  Future<Result<void>> addGroupMembers(
    String accountId,
    String chatGid,
    List<int> userIds,
  );

  /// Removes [userIds] from group [chatGid]; only its owner may.
  Future<Result<void>> removeGroupMembers(
    String accountId,
    String chatGid,
    List<int> userIds,
  );
}

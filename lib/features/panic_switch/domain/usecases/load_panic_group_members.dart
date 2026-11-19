import '../../../../core/error/result.dart';
import '../../../chat/domain/entities/chat_user.dart';
import '../../../chat/domain/repositories/chat_repository.dart';

/// The members of a group who could send the sticker: everyone but the user,
/// by name.
class LoadPanicGroupMembers {
  const LoadPanicGroupMembers(this._chats);

  final ChatRepository _chats;

  Future<Result<List<ChatUser>>> call({
    required String accountId,
    required String chatGid,
  }) async {
    final users = {
      for (final u in await _chats.watchUsers(accountId).first) u.userId: u,
    };
    final self = await _chats.watchSelfUserId(accountId).first;
    return (await _chats.members(accountId, chatGid)).fold(
      (ids) => Ok(
        [
          for (final id in ids)
            if (id != self) ?users[id],
        ]..sort((a, b) => _name(a).compareTo(_name(b))),
      ),
      Err.new,
    );
  }

  static String _name(ChatUser u) =>
      (u.realname.isEmpty ? u.account : u.realname).toLowerCase();
}

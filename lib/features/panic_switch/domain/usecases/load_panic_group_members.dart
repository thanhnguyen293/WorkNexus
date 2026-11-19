import '../../../../core/error/result.dart';
import '../entities/panic_member.dart';
import '../repositories/panic_chat_gateway.dart';

/// The members of a group who could send the sticker: everyone but the user,
/// by name.
class LoadPanicGroupMembers {
  const LoadPanicGroupMembers(this._chats);

  final PanicChatGateway _chats;

  Future<Result<List<PanicMember>>> call({
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

  static String _name(PanicMember u) => u.displayName.toLowerCase();
}

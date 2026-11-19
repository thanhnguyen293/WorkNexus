import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/chat_group_repository.dart';
import '../datasources/xxd/xxd_packet.dart';
import 'chat_session.dart';

/// Sends [request] over [session] and stores the reply, as the chat
/// repository does for every request.
typedef ChatRequestSender =
    Future<Result<void>> Function(
      String accountId,
      ChatSession session,
      XxdRequest request,
    );

/// [ChatGroupRepository] over xxd, following the official ZenTao client's
/// calls. Every reply (also pushed to the other members) is stored by the
/// chat repository's ingestor, which is what updates the UI.
class XxdChatGroupRepository implements ChatGroupRepository {
  XxdChatGroupRepository({required this._session, required this._send});

  final ChatSession? Function(String accountId) _session;
  final ChatRequestSender _send;

  @override
  Future<Result<void>> renameGroupChat(
    String accountId,
    String chatGid,
    String name,
  ) async {
    final session = _session(accountId);
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    // The reply (`{gid, name}`, also pushed to the other members) renames
    // it locally.
    return _send(
      accountId,
      session,
      XxdRequest('chatRename', params: [chatGid, name]),
    );
  }

  @override
  Future<Result<void>> dismissGroupChat(
    String accountId,
    String chatGid,
  ) async {
    final session = _session(accountId);
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    // The reply carries `dismissDate`, which takes it off the chat list.
    return _send(
      accountId,
      session,
      XxdRequest('chatDismiss', params: [chatGid]),
    );
  }

  @override
  Future<Result<void>> addGroupMembers(
    String accountId,
    String chatGid,
    List<int> userIds,
  ) => _changeMembers(accountId, 'chatInvite', chatGid, userIds);

  @override
  Future<Result<void>> removeGroupMembers(
    String accountId,
    String chatGid,
    List<int> userIds,
  ) => _changeMembers(accountId, 'chatKick', chatGid, userIds);

  @override
  Future<Result<void>> leaveGroupChat(String accountId, String chatGid) async {
    final session = _session(accountId);
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    // The reply is the group without this account, which takes it off the
    // chat list (see the ingestor).
    return _send(
      accountId,
      session,
      XxdRequest('chatLeave', params: [chatGid]),
    );
  }

  @override
  Future<Result<void>> setChatCategory(
    String accountId,
    List<String> chatGids,
    String category,
  ) async {
    final session = _session(accountId);
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    // The reply (`{gids, category}`) refiles them locally.
    return _send(
      accountId,
      session,
      XxdRequest('chatSetCategory', params: [chatGids, category]),
    );
  }

  @override
  Future<Result<void>> setGroupSettings(
    String accountId,
    String chatGid, {
    required bool isPublic,
    required bool adminInvite,
    required String committers,
  }) async {
    final session = _session(accountId);
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final result = await _send(
      accountId,
      session,
      XxdRequest(
        'chatSetConfig',
        params: [
          chatGid,
          {
            'public': isPublic,
            'adminInvite': adminInvite,
            'committers': committers,
          },
        ],
      ),
    );
    if (result is Ok) return result;
    // Servers older than `chatSetConfig` (the official client checks the
    // version) take the two settings one by one and have no `adminInvite`.
    final visibility = await _send(
      accountId,
      session,
      XxdRequest('chatSetVisibility', params: [chatGid, isPublic]),
    );
    if (visibility is Err) return result;
    return _send(
      accountId,
      session,
      XxdRequest('chatSetCommitters', params: [chatGid, committers]),
    );
  }

  @override
  Future<Result<void>> setGroupAdmins(
    String accountId,
    String chatGid,
    List<int> userIds, {
    required bool admin,
  }) async {
    final session = _session(accountId);
    final self = session?.selfUserId;
    if (session == null || self == null) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    return _send(
      accountId,
      session,
      XxdRequest(
        admin ? 'chatAddAdmins' : 'chatRemoveAdmins',
        params: [chatGid, userIds, self],
      ),
    );
  }

  @override
  Future<Result<void>> transferGroupOwnership(
    String accountId,
    String chatGid,
    int userId,
  ) async {
    final session = _session(accountId);
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    // The reply is the whole group with its new owner.
    return _send(
      accountId,
      session,
      XxdRequest('chatChangeOwnership', params: [chatGid, userId]),
    );
  }

  /// `chatInvite` / `chatKick`: the reply is the group with its new members,
  /// also pushed to them.
  Future<Result<void>> _changeMembers(
    String accountId,
    String method,
    String chatGid,
    List<int> userIds,
  ) async {
    final session = _session(accountId);
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    return _send(
      accountId,
      session,
      XxdRequest(method, params: [chatGid, userIds]),
    );
  }
}

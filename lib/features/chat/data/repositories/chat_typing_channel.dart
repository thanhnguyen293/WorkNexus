import 'dart:async';

import '../../../../core/error/result.dart';
import '../../domain/value_objects/chat_typing_signal.dart';
import '../datasources/xxd/xxd_connection_state.dart';
import '../datasources/xxd/xxd_packet.dart';
import '../mappers/chat_mappers.dart';
import 'chat_session.dart';

/// Loads a group's member ids (`chatGetMembers`).
typedef ChatMembersLoader =
    Future<Result<List<int>>> Function(String accountId, String chatGid);

/// Typing status over xxd: sends `chattyping` and turns the server's
/// `chattyping` pushes into [ChatTypingSignal]s. It lasts seconds, so unlike
/// every other packet nothing here is stored.
class ChatTypingChannel {
  ChatTypingChannel(this._members);

  final ChatMembersLoader _members;
  final _signals = <String, StreamController<ChatTypingSignal>>{};

  /// accountId → group gid → member ids, fetched once per session.
  final _groupMembers = <String, Map<String, List<int>>>{};

  Stream<ChatTypingSignal> watch(String accountId) =>
      _channel(accountId).stream;

  /// Whether [packet] is a typing push; it is consumed here, not ingested.
  bool handle(String accountId, XxdResponse packet) {
    if (packet.apiName != 'chattyping') return false;
    final data = packet.data;
    if (!packet.isSuccess || data is! Map) return true;
    final gid = data['cgid'];
    final user = _int(data['user']);
    final typing = switch (data['typing']) {
      final bool b => b,
      final num n => n != 0,
      _ => null,
    };
    if (gid is String && user != null && typing != null) {
      _channel(
        accountId,
      ).add(ChatTypingSignal(chatGid: gid, userId: user, typing: typing));
    }
    return true;
  }

  /// Tells the chat's other members whether the user is [typing]. A one-to-
  /// one chat addresses its peer, as the official client does; a group
  /// addresses its members.
  Future<Result<void>> send(
    ChatSession? session,
    String accountId,
    String chatGid, {
    required bool typing,
  }) async {
    // The connection knows who signed in before `selfUserId` is copied over
    // from its state change, which may still be on its way.
    final self = switch (session?.connection.state) {
      XxdOnline(:final session) => session.userId,
      _ => null,
    };
    if (session == null || self == null) return const Ok(null);
    final List<int> users;
    final peer = peerOf(chatGid, self);
    if (peer != null) {
      users = [peer];
    } else {
      final members = await _groupMembersOf(accountId, chatGid);
      switch (members) {
        case Ok(:final value):
          users = [
            for (final id in value)
              if (id != self) id,
          ];
        case Err(:final failure):
          return Err(failure);
      }
    }
    if (users.isEmpty) return const Ok(null);
    return session.connection.notify(
      XxdRequest(
        'chattyping',
        fields: {'cgid': chatGid, 'users': users, 'typing': typing},
      ),
    );
  }

  /// Drops what was cached for the account's session (members may have
  /// changed by the next sign-in).
  void forget(String accountId) => _groupMembers.remove(accountId);

  Future<Result<List<int>>> _groupMembersOf(
    String accountId,
    String chatGid,
  ) async {
    final cached = _groupMembers[accountId]?[chatGid];
    if (cached != null) return Ok(cached);
    final loaded = await _members(accountId, chatGid);
    if (loaded case Ok(:final value)) {
      (_groupMembers[accountId] ??= {})[chatGid] = value;
    }
    return loaded;
  }

  StreamController<ChatTypingSignal> _channel(String accountId) =>
      _signals.putIfAbsent(accountId, StreamController.broadcast);

  static int? _int(Object? v) => switch (v) {
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };
}

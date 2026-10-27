import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../entities/message_reaction.dart';
import '../repositories/chat_repository.dart';
import 'encode_emoji.dart';
import 'retract_message.dart';

/// Reacts to a message with an emoji, or takes the user's own reaction with
/// that emoji back. A reaction is a reply made of just the emoji (see
/// `ChatMessageReaction`), so taking it back retracts that reply — which xxd
/// allows only for a couple of minutes.
class ToggleReaction {
  ToggleReaction(this._repository, {DateTime Function()? now})
    : _retract = RetractMessage(_repository, now: now);

  final ChatRepository _repository;
  final RetractMessage _retract;

  /// Whether the user's own [reaction] can still be taken back.
  bool canRemove(MessageReaction reaction) {
    final mine = reaction.mine;
    return mine != null && _retract.canRetract(mine);
  }

  Future<Result<void>> call(
    ChatMessage message,
    String emoji, {
    required List<MessageReaction> reactions,
  }) async {
    final serverId = message.serverId;
    if (serverId == null || message.deleted) {
      return const Err(UnexpectedFailure('Nothing to react to yet'));
    }
    final existing = reactions.where((r) => r.emoji == emoji).firstOrNull;
    final mine = existing?.mine;
    if (existing != null && mine != null) {
      if (!canRemove(existing)) {
        return const Err(ExpiredFailure('Reaction can no longer be removed'));
      }
      return _retract(mine);
    }
    final code = const EncodeEmoji()(emoji.trim());
    if (code.isEmpty) {
      return const Err(UnexpectedFailure('No emoji to send'));
    }
    return _repository.sendEmoji(
      message.accountId,
      message.chatGid,
      code,
      replyToId: serverId,
    );
  }
}

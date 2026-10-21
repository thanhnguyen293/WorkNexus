import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_message.dart';

part 'message_reaction.freezed.dart';

/// Everyone who reacted to one message with the same [emoji].
@freezed
abstract class MessageReaction with _$MessageReaction {
  const factory MessageReaction({
    required String emoji,

    /// Who reacted, oldest first.
    required List<int> userIds,

    /// The reaction message the current user sent, when they did — what
    /// removing their reaction retracts.
    ChatMessage? mine,
  }) = _MessageReaction;

  const MessageReaction._();

  int get count => userIds.length;
}

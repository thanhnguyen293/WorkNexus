import 'package:collection/collection.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/message_reaction.dart';
import '../../domain/usecases/build_reactions.dart';

/// Turns a chat's replies into the reactions to its messages, emitting only
/// when they change.
class ChatReactionsWatcher {
  const ChatReactionsWatcher();

  Stream<Map<int, List<MessageReaction>>> call(
    Stream<List<ChatMessage>> replies,
  ) => replies
      .map(const BuildReactions().call)
      .distinct(const DeepCollectionEquality().equals);
}

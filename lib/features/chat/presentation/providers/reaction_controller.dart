import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/message_reaction.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/toggle_reaction.dart';
import 'chat_providers.dart';

/// The reaction commands of the chat view; each delegates to [ToggleReaction].
class ReactionController {
  ReactionController(ChatRepository repository)
    : _toggle = ToggleReaction(repository);

  final ToggleReaction _toggle;

  /// Whether the user's own [reaction] can still be taken back.
  bool canRemove(MessageReaction reaction) => _toggle.canRemove(reaction);

  /// Reacts to [message] with [emoji], or takes the user's own such reaction
  /// back, given the [reactions] it has now.
  Future<Result<void>> toggle(
    ChatMessage message,
    String emoji, {
    required List<MessageReaction> reactions,
  }) => _toggle(message, emoji, reactions: reactions);
}

final reactionControllerProvider = Provider<ReactionController>(
  (ref) => ReactionController(ref.watch(chatRepositoryProvider)),
);

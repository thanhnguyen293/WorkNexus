import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/entities/message_reaction.dart';
import '../providers/chat_providers.dart';
import '../providers/reaction_controller.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';

/// Under a message: what people reacted to it with, one chip per emoji with
/// how many used it. The user's own are tinted; tapping a chip adds the
/// user's reaction with that emoji or takes it back.
class ReactionChips extends ConsumerWidget {
  const ReactionChips({
    super.key,
    required this.chat,
    required this.message,
    required this.users,
    required this.alignEnd,
  });

  final ChatThreadKey chat;
  final ChatMessage message;
  final Map<int, ChatUser> users;
  final bool alignEnd;

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    List<MessageReaction> reactions,
    MessageReaction reaction,
  ) async {
    final result = await ref
        .read(reactionControllerProvider)
        .toggle(message, reaction.emoji, reactions: reactions);
    if (result case Err(:final failure)) {
      if (context.mounted) showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId = message.serverId;
    final reactions = serverId == null
        ? null
        : ref.watch(
            chatReactionsProvider(chat).select((m) => m.value?[serverId]),
          );
    if (reactions == null || reactions.isEmpty) return const SizedBox.shrink();
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.only(top: s.xs),
      child: Wrap(
        alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
        spacing: s.xs,
        runSpacing: s.xs,
        children: [
          for (final reaction in reactions)
            _ReactionChip(
              reaction: reaction,
              tooltip: l.chatReactionBy(
                reaction.userIds
                    .map((id) => chatUserName(context, users, id))
                    .join(', '),
                reaction.emoji,
              ),
              onTap: () => _toggle(context, ref, reactions, reaction),
            ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    required this.tooltip,
    required this.onTap,
  });

  final MessageReaction reaction;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final mine = reaction.mine != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: mine ? c.selectionFill : c.surface,
        shape: StadiumBorder(
          side: BorderSide(color: mine ? c.selectionBorder : c.border),
        ),
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reaction.emoji, style: context.typography.body),
                if (reaction.count > 1) ...[
                  SizedBox(width: s.xs),
                  Text(
                    '${reaction.count}',
                    style: context.typography.captionStrong.copyWith(
                      color: mine ? c.accent : c.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

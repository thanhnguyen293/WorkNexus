import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'typing_dots.dart';

/// The second line of a chat-list row: the last message, or — crossfading
/// in while someone types — who is typing.
class ConversationPreviewLine extends StatelessWidget {
  const ConversationPreviewLine({
    super.key,
    required this.chat,
    this.lastSender,
    this.typing,
  });

  final ChatConversation chat;

  /// Who sent the last message, shown before its preview (groups).
  final String? lastSender;

  /// Who is typing; replaces the preview while set.
  final String? typing;

  @override
  Widget build(BuildContext context) {
    final typing = this.typing;
    return AnimatedSwitcher(
      duration: AppMotion.base,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: typing != null
          ? _Typing(key: const ValueKey('typing'), label: typing)
          : _LastMessage(
              key: const ValueKey('last'),
              chat: chat,
              lastSender: lastSender,
            ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        TypingDots(color: c.accent, size: context.spacing.xs),
        SizedBox(width: context.spacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.bodySm.copyWith(color: c.accent),
          ),
        ),
      ],
    );
  }
}

class _LastMessage extends ConsumerWidget {
  const _LastMessage({super.key, required this.chat, this.lastSender});

  final ChatConversation chat;
  final String? lastSender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final last = chat.lastMessage;
    final unread = chat.unreadCount > 0;
    return Text.rich(
      TextSpan(
        children: [
          if (lastSender case final sender?)
            TextSpan(
              text: '$sender: ',
              // Set apart by color only, a step above the preview: bolder or
              // full-ink text here outweighs the chat title above it.
              style: context.typography.bodySm.copyWith(
                color: unread
                    ? c.textPrimary
                    : Color.lerp(c.textSecondary, c.textPrimary, 0.4),
              ),
            ),
          TextSpan(
            text: last == null
                ? ''
                : chatPreview(
                    context,
                    last,
                    reactions: ref.watch(chatReactionsOnProvider),
                  ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.typography.bodySm.copyWith(
        color: unread ? c.textPrimary : c.textSecondary,
      ),
    );
  }
}

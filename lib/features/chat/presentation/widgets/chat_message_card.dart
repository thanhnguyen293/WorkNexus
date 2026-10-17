import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_side_panel_frame.dart';

/// A message set apart beside the chat — a pinned message, a thread's root:
/// who sent it and what the card is ([label]), the message ([body]), then
/// when it was sent and a link back to it in the chat.
class ChatMessageCard extends StatelessWidget {
  const ChatMessageCard({
    super.key,
    required this.message,
    required this.users,
    required this.label,
    required this.labelIcon,
    required this.body,
    this.onViewOriginal,
    this.trailing,
  });

  final ChatMessage message;
  final Map<int, ChatUser> users;
  final String label;
  final IconData labelIcon;
  final Widget body;

  /// Null hides the "View original message" link (no server id yet).
  final VoidCallback? onViewOriginal;

  /// Beside the sender (e.g. an unpin button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final sender = message.senderId;
    return ChatPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChatAvatar(
                name: chatUserName(context, users, sender),
                imageUrl: chatAvatarUrl(users, sender),
                verified: chatVerifiedBadge(context, users, sender),
              ),
              SizedBox(width: s.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chatUserName(context, users, sender),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    SizedBox(height: s.xxs),
                    Row(
                      children: [
                        Icon(labelIcon, size: s.xl2, color: c.accent),
                        SizedBox(width: s.xs),
                        Text(
                          label,
                          style: context.typography.secondary.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          SizedBox(height: s.lg),
          body,
          SizedBox(height: s.lg),
          _SentAtFooter(sentAt: message.sentAt, onViewOriginal: onViewOriginal),
        ],
      ),
    );
  }
}

/// "29/05/2026 at 09:56 | View original message".
class _SentAtFooter extends StatelessWidget {
  const _SentAtFooter({required this.sentAt, required this.onViewOriginal});

  final DateTime sentAt;
  final VoidCallback? onViewOriginal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final style = context.typography.secondary.copyWith(color: c.textTertiary);
    final when = l.chatDateAtTime(
      DateFormat('dd/MM/yyyy').format(sentAt),
      DateFormat('HH:mm').format(sentAt),
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(when, style: style),
        if (onViewOriginal case final open?) ...[
          Text(' | ', style: style),
          HoverRegion(
            builder: (context, hovered, _) => HoverSurface(
              onTap: open,
              tintOnHover: false,
              borderRadius: BorderRadius.circular(context.radii.sm),
              child: Text(
                l.chatViewOriginal,
                style: context.typography.secondaryStrong.copyWith(
                  color: c.accent,
                  decoration: hovered ? TextDecoration.underline : null,
                  decorationColor: c.accent,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

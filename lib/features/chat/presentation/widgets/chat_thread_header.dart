import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_appearance_menu.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_notification_toggle.dart';
import 'chat_panels.dart';

/// Top of an open chat: avatar, title and, for groups, the member count (for
/// one-to-one chats, the other person's account).
class ChatThreadHeader extends ConsumerWidget {
  const ChatThreadHeader({
    super.key,
    required this.thread,
    required this.chat,
    required this.users,
  });

  final ChatThreadKey thread;
  final ChatConversation? chat;
  final Map<int, ChatUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final chat = this.chat;
    final title = chat == null ? '' : chatTitle(context, chat, users);
    final oneToOne = chat?.type == ChatType.one2one;
    final peer = oneToOne ? users[chat?.peerUserId] : null;
    final members = oneToOne
        ? null
        : ref.watch(chatMemberCountProvider(thread)).asData?.value;
    final subtitle = switch (members) {
      Ok(:final value) => l.chatMembers(value),
      _ => peer?.account,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xl4,
        vertical: context.spacing.xl,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Row(
        children: [
          ChatAvatar(
            name: title,
            imageUrl: peer?.avatarUrl,
            size: ChatAvatarSize.large,
          ),
          SizedBox(width: context.spacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.titleLg.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Row(
                    children: [
                      Icon(
                        oneToOne ? Icons.alternate_email : Icons.person_outline,
                        size: context.spacing.xl3,
                        color: c.textSecondary,
                      ),
                      SizedBox(width: context.spacing.xs),
                      Text(
                        subtitle,
                        style: context.typography.secondary.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.chatInfo,
            isSelected:
                ref.watch(chatSidePanelProvider(thread)) == ChatSidePanel.info,
            onPressed: () =>
                toggleChatSidePanel(ref, thread, ChatSidePanel.info),
            icon: Icon(Icons.info_outline_rounded, color: c.textSecondary),
          ),
          const ChatNotificationToggle(),
          const ChatAppearanceMenu(),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_info_dialog.dart';
import 'chat_labels.dart';
import 'chat_mute_toggle.dart';
import 'chat_side_panel_frame.dart';

/// Top of an open chat: avatar, title and, for groups, the member count (for
/// one-to-one chats, the other person's account). Clicking them shows the
/// chat or group info.
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
        // `value`, not `asData`: keeps the last count while it refreshes.
        : ref.watch(chatMemberCountProvider(thread)).value;
    final avatar = chat == null ? null : chatAvatarStyle(chat, users);
    final presence = oneToOne ? chatPresenceOf(users, chat?.peerUserId) : null;
    final subtitle = switch (members) {
      Ok(:final value) => l.chatMembers(value),
      _ when presence != null => chatPresenceLabel(context, presence),
      _ => peer?.account,
    };
    return Container(
      height: kChatHeaderHeight,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl4),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Row(
        children: [
          Expanded(
            child: _InfoTap(
              onTap: chat == null
                  ? null
                  : () => showChatInfo(
                      context,
                      ref,
                      thread: thread,
                      chat: chat,
                      users: users,
                    ),
              child: Row(
                children: [
                  ChatAvatar(
                    name: title,
                    imageUrl: avatar?.imageUrl,
                    label: avatar?.label,
                    background: avatar?.background,
                    presence: presence,
                    verified: oneToOne
                        ? chatVerifiedBadge(context, users, chat?.peerUserId)
                        : null,
                    size: ChatAvatarSize.large,
                  ),
                  SizedBox(width: context.spacing.xl),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.titleLg.copyWith(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null)
                          Row(
                            children: [
                              Icon(
                                !oneToOne
                                    ? LucideIcons.user300
                                    : presence != null
                                    ? Icons.circle
                                    : LucideIcons.atSign300,
                                size: presence != null
                                    ? context.spacing.md
                                    : context.spacing.xl3,
                                color: presence?.isAround ?? false
                                    ? c.success
                                    : c.textSecondary,
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
                ],
              ),
            ),
          ),
          if (chat case final chat?) ChatMuteToggle(chat: chat),
        ],
      ),
    );
  }
}

/// The avatar and title: a click shows the chat (or group) info.
class _InfoTap extends StatelessWidget {
  const _InfoTap({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: AppL10n.of(context).chatInfo,
    child: MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    ),
  );
}

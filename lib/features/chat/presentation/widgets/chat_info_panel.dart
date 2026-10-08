import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_detail_row.dart';
import 'chat_labels.dart';
import 'chat_member_list.dart';
import 'chat_panels.dart';
import 'chat_side_panel_frame.dart';

/// Beside the chat: who the other person is (one-to-one) or what the group
/// is — owner, creation date, pinned messages and members — as cards.
class ChatInfoPanel extends ConsumerWidget {
  const ChatInfoPanel({
    super.key,
    required this.thread,
    required this.chat,
    required this.users,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final Map<int, ChatUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final oneToOne = chat.type == ChatType.one2one;
    final peer = oneToOne ? users[chat.peerUserId] : null;
    final title = chatTitle(context, chat, users);
    final owner = users.values
        .where((u) => u.account == chat.ownerAccount)
        .firstOrNull;
    final created = chat.createdAt;
    final members = oneToOne
        ? null
        : ref.watch(chatMembersProvider(thread)).value;
    final subtitle = switch (members) {
      Ok(:final value) => l.chatMembers(value.length),
      _ => peer == null ? null : '@${peer.account}',
    };

    final details = [
      if (peer?.role case final role?)
        ChatDetailRow(
          icon: Icons.badge_outlined,
          label: l.chatRole,
          value: role,
        ),
      if (peer?.email case final email?)
        ChatDetailRow(
          icon: Icons.mail_outline,
          label: l.chatEmail,
          value: email,
        ),
      if (peer?.mobile case final mobile?)
        ChatDetailRow(
          icon: Icons.smartphone,
          label: l.chatMobile,
          value: mobile,
        ),
      if (peer?.phone case final phone?)
        ChatDetailRow(
          icon: Icons.call_outlined,
          label: l.chatPhone,
          value: phone,
        ),
      if (!oneToOne && chat.ownerAccount != null)
        ChatDetailRow(
          icon: Icons.verified_user_outlined,
          label: l.chatOwner,
          value: owner?.realname ?? chat.ownerAccount ?? '',
        ),
      if (!oneToOne && created != null)
        ChatDetailRow(
          icon: Icons.event_outlined,
          label: l.chatCreatedOn,
          value: DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(created),
        ),
    ];

    return ChatSidePanelFrame(
      title: l.chatInfo,
      onClose: () =>
          ref.read(chatSidePanelProvider(thread).notifier).state = null,
      child: ListView(
        padding: EdgeInsets.all(s.xl3),
        children: [
          SizedBox(height: s.md),
          Center(
            child: ChatAvatar(
              name: title,
              imageUrl: peer?.avatarUrl,
              diameter: s.xl6 * 2,
            ),
          ),
          SizedBox(height: s.xl),
          SelectableText(
            title,
            textAlign: TextAlign.center,
            style: context.typography.titleLg.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: context.typography.secondary.copyWith(
                color: c.textSecondary,
              ),
            ),
          SizedBox(height: s.xl4),
          if (details.isNotEmpty)
            _Card(
              child: Column(
                children: [
                  for (final (i, row) in details.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : s.lg),
                      child: row,
                    ),
                ],
              ),
            ),
          _Card(
            padding: EdgeInsets.zero,
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.radii.lg),
              ),
              leading: Icon(Icons.push_pin_outlined, color: c.accent),
              title: Text(
                l.chatPinnedMessages,
                style: context.typography.bodyStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${chat.pinnedMessageIds.length}',
                    style: context.typography.bodyStrong.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.textTertiary),
                ],
              ),
              onTap: () =>
                  toggleChatSidePanel(ref, thread, ChatSidePanel.pinned),
            ),
          ),
          if (!oneToOne)
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.chatMembersTitle,
                    style: context.typography.bodyStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  SizedBox(height: s.md),
                  ChatMemberList(
                    chat: thread,
                    users: users,
                    ownerAccount: chat.ownerAccount,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One section of the panel: a surface card with a hairline border.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Container(
      margin: EdgeInsets.only(bottom: s.xl),
      padding: padding ?? EdgeInsets.all(s.xl3),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.fromBorderSide(context.hairlineSide),
      ),
      child: child,
    );
  }
}

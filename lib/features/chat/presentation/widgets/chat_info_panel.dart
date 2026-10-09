import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/value_objects/chat_presence.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_detail_row.dart';
import 'chat_group_avatar_dialog.dart';
import 'chat_info_files_section.dart';
import 'chat_info_storage_card.dart';
import 'chat_labels.dart';
import 'chat_layout.dart';
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
    this.onClose,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final Map<int, ChatUser> users;

  /// Closes it where it is shown as a dialog; beside the chat it closes
  /// itself (and only in a narrow window).
  final VoidCallback? onClose;

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
    final avatar = chatAvatarStyle(chat, users);
    final members = oneToOne
        ? null
        : ref.watch(chatMembersProvider(thread)).value;
    final subtitle = switch (members) {
      Ok(:final value) => l.chatMembers(value.length),
      _ when peer?.status != null => chatPresenceLabel(
        context,
        ChatPresence.fromStatus(peer?.status),
      ),
      _ => peer == null ? null : '@${peer.account}',
    };

    final details = [
      if (peer?.role case final role?)
        ChatDetailRow(
          icon: PhosphorIconsLight.identificationBadge,
          label: l.chatRole,
          value: chatRoleLabel(context, role),
          spaced: false,
        ),
      if (peer?.email case final email?)
        ChatDetailRow(
          icon: PhosphorIconsLight.envelopeSimple,
          label: l.chatEmail,
          value: email,
          spaced: false,
        ),
      if (peer?.mobile case final mobile?)
        ChatDetailRow(
          icon: PhosphorIconsLight.deviceMobile,
          label: l.chatMobile,
          value: mobile,
          spaced: false,
        ),
      if (peer?.phone case final phone?)
        ChatDetailRow(
          icon: PhosphorIconsLight.phone,
          label: l.chatPhone,
          value: phone,
          spaced: false,
        ),
      if (!oneToOne && chat.ownerAccount != null)
        ChatDetailRow(
          icon: PhosphorIconsLight.shieldCheck,
          label: l.chatOwner,
          value: owner?.realname ?? chat.ownerAccount ?? '',
          spaced: false,
        ),
      if (!oneToOne && created != null)
        ChatDetailRow(
          icon: PhosphorIconsLight.calendarBlank,
          label: l.chatCreatedOn,
          value: DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(created),
          spaced: false,
        ),
    ];

    return ChatSidePanelFrame(
      title: l.chatInfo,
      // With room the info panel stays: it only closes in a narrow window.
      onClose:
          onClose ??
          (ChatLayoutScope.of(context).infoRoom
              ? null
              : () => closeChatSidePanel(ref, thread)),
      child: ListView(
        padding: EdgeInsets.all(s.xl),
        children: [
          Center(
            child: ChatAvatar(
              name: title,
              imageUrl: avatar.imageUrl,
              label: avatar.label,
              background: avatar.background,
              presence: oneToOne
                  ? chatPresenceOf(users, chat.peerUserId)
                  : null,
              verified: oneToOne
                  ? chatVerifiedBadge(context, users, chat.peerUserId)
                  : null,
              diameter: s.xl6 * 2,
            ),
          ),
          if (!oneToOne && ref.watch(chatCanPinProvider(thread)))
            Center(
              child: TextButton.icon(
                onPressed: () => ChatGroupAvatarDialog.show(
                  context,
                  thread: thread,
                  chat: chat,
                  title: title,
                ),
                icon: const Icon(PhosphorIconsLight.camera),
                label: Text(l.chatChangeGroupAvatar),
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
            ChatPanelCard(
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
          ChatPanelCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: s.xl),
              visualDensity: VisualDensity.compact,
              horizontalTitleGap: s.lg,
              minLeadingWidth: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.radii.lg),
              ),
              leading: Icon(PhosphorIconsLight.pushPin, color: c.accent),
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
                  Icon(PhosphorIconsLight.caretRight, color: c.textTertiary),
                ],
              ),
              onTap: () => toggleChatSidePanel(
                ref,
                thread,
                ChatSidePanel.pinned,
                infoRoom: ChatLayoutScope.of(context).infoRoom,
              ),
            ),
          ),
          ChatInfoFilesSection(thread: thread),
          ChatInfoStorageCard(thread: thread),
          if (!oneToOne)
            ChatPanelCard(
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

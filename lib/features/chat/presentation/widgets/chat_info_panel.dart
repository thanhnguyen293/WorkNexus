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
    // The kept count the chat header shows too, so switching chats does not
    // blank "N members" while the member list is refetched.
    final members = oneToOne
        ? null
        : ref.watch(chatMemberCountProvider(thread)).value;
    final subtitle = switch (members) {
      Ok(:final value) => l.chatMembers(value),
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
          value: chatRoleLabel(
            context,
            role,
            serverNames:
                ref.watch(chatRoleNamesProvider(thread.accountId)).value ??
                const {},
          ),
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
          _PanelLink(
            icon: PhosphorIconsLight.pushPin,
            label: l.chatPinnedMessages,
            count: chat.pinnedMessageIds.length,
            onTap: () => toggleChatSidePanel(
              ref,
              thread,
              ChatSidePanel.pinned,
              infoRoom: ChatLayoutScope.of(context).infoRoom,
            ),
          ),
          if (!oneToOne)
            _PanelLink(
              icon: PhosphorIconsLight.usersThree,
              label: l.chatMembersTitle,
              count: switch (members) {
                Ok(:final value) => value,
                _ => null,
              },
              onTap: () => toggleChatSidePanel(
                ref,
                thread,
                ChatSidePanel.members,
                infoRoom: ChatLayoutScope.of(context).infoRoom,
              ),
            ),
          ChatInfoFilesSection(thread: thread),
          ChatInfoStorageCard(thread: thread),
        ],
      ),
    );
  }
}

/// A card that opens a sub-panel of the info: icon, label, count, chevron.
class _PanelLink extends StatelessWidget {
  const _PanelLink({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Null while unknown.
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return ChatPanelCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: s.xl),
        visualDensity: VisualDensity.compact,
        horizontalTitleGap: s.lg,
        minLeadingWidth: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radii.lg),
        ),
        leading: Icon(icon, color: c.accent),
        title: Text(
          label,
          style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count case final n?)
              Text(
                '$n',
                style: context.typography.bodyStrong.copyWith(
                  color: c.textSecondary,
                ),
              ),
            Icon(PhosphorIconsLight.caretRight, color: c.textTertiary),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

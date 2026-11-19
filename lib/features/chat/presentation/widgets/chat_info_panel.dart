import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/privacy_mask.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/value_objects/chat_presence.dart';
import '../../domain/value_objects/chat_privacy_part.dart';
import '../providers/chat_group_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_detail_row.dart';
import 'chat_group_actions.dart';
import 'chat_group_edit_controls.dart';
import 'chat_group_settings_dialog.dart';
import 'chat_info_files_section.dart';
import 'chat_info_panel_link.dart';
import 'chat_info_storage_card.dart';
import 'chat_labels.dart';
import 'chat_layout.dart';
import 'chat_panels.dart';
import 'chat_privacy_mask.dart';
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
    // My Cloud's "peer" is you: your own contact details are left out.
    final withPeer = oneToOne && !chat.isMyCloud;
    final peer = withPeer ? users[chat.peerUserId] : null;
    final title = chatTitle(context, chat, users);
    final titleStyle = context.typography.titleLg.copyWith(
      color: c.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = context.typography.secondary.copyWith(
      color: c.textSecondary,
    );
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
      _ when chat.isMyCloud => l.chatMyCloudHint,
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
          icon: LucideIcons.idCard300,
          label: l.chatRole,
          value: chatRoleLabel(
            context,
            role,
            serverNames:
                ref.watch(chatRoleNamesProvider(thread.accountId)).value ??
                const {},
          ),
          spaced: false,
          privacyPart: ChatPrivacyPart.identity,
        ),
      if (peer?.email case final email?)
        ChatDetailRow(
          icon: LucideIcons.mail300,
          label: l.chatEmail,
          value: email,
          spaced: false,
          privacyPart: ChatPrivacyPart.identity,
        ),
      if (peer?.mobile case final mobile?)
        ChatDetailRow(
          icon: LucideIcons.smartphone300,
          label: l.chatMobile,
          value: mobile,
          spaced: false,
          privacyPart: ChatPrivacyPart.identity,
        ),
      if (peer?.phone case final phone?)
        ChatDetailRow(
          icon: LucideIcons.phone300,
          label: l.chatPhone,
          value: phone,
          spaced: false,
          privacyPart: ChatPrivacyPart.identity,
        ),
      if (!oneToOne && chat.ownerAccount != null)
        ChatDetailRow(
          icon: LucideIcons.shieldCheck300,
          label: l.chatOwner,
          value: owner?.realname ?? chat.ownerAccount ?? '',
          spaced: false,
          privacyPart: ChatPrivacyPart.identity,
        ),
      if (!oneToOne && created != null)
        ChatDetailRow(
          icon: LucideIcons.calendar300,
          label: l.chatCreatedOn,
          value: DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(created),
          spaced: false,
          privacyPart: ChatPrivacyPart.identity,
        ),
    ];

    return ChatSidePanelFrame(
      title: l.chatInfo,
      // Resting beside the chat, it is hidden with the header's info button.
      onClose:
          onClose ??
          (watchChatInfoDocked(
                ref,
                infoRoom: ChatLayoutScope.of(context).infoRoom,
              )
              ? null
              : () => closeChatSidePanel(ref, thread)),
      // Pointing anywhere on the panel shows all of it while it is hidden.
      child: PrivacyRevealRegion(
        child: ListView(
          padding: EdgeInsets.all(s.xl),
          children: [
            Center(
              child: ChatPrivacyMask(
                part: ChatPrivacyPart.identity,
                mask: ChatAvatar(
                  name: '',
                  masked: true,
                  icon: oneToOne ? null : LucideIcons.users300,
                  diameter: s.xl6 * 2,
                ),
                child: ChatGroupAvatarEditor(
                  thread: thread,
                  chat: chat,
                  title: title,
                  child: ChatAvatar(
                    name: title,
                    imageUrl: avatar.imageUrl,
                    label: avatar.label,
                    background: avatar.background,
                    icon: avatar.icon,
                    presence: withPeer
                        ? chatPresenceOf(users, chat.peerUserId)
                        : null,
                    verified: withPeer
                        ? chatVerifiedBadge(context, users, chat.peerUserId)
                        : null,
                    diameter: s.xl6 * 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: s.xl),
            ChatPrivacyMask(
              part: ChatPrivacyPart.identity,
              mask: Text(
                kPrivacyMaskText,
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
              child: ChatGroupTitleEditor(
                thread: thread,
                chat: chat,
                child: SelectableText(
                  title,
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
              ),
            ),
            if (subtitle != null)
              // The peer's account names them as much as the title does.
              ChatPrivacyMask(
                part: ChatPrivacyPart.identity,
                mask: Text(
                  // Only the account starts with "@"; a count or status stays.
                  subtitle.startsWith('@') ? kPrivacyMaskText : subtitle,
                  textAlign: TextAlign.center,
                  style: subtitleStyle,
                ),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: subtitleStyle,
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
            ChatInfoPanelLink(
              icon: LucideIcons.pin300,
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
              ChatInfoPanelLink(
                icon: LucideIcons.users300,
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
            if (ref.watch(chatGroupRightsProvider(thread)).editSettings)
              ChatInfoPanelLink(
                icon: LucideIcons.settings2300,
                label: l.chatGroupSettings,
                count: null,
                onTap: () => ChatGroupSettingsDialog.show(
                  context,
                  thread: thread,
                  chat: chat,
                ),
              ),
            ChatInfoFilesSection(thread: thread),
            ChatInfoStorageCard(thread: thread),
            if (!oneToOne)
              ChatGroupExitButton(
                thread: thread,
                chat: chat,
                title: title,
                onExited: onClose,
              ),
          ],
        ),
      ),
    );
  }
}

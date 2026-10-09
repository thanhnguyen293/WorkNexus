import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/order_chat_roles.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_role_tabs.dart';
import 'chat_side_panel_frame.dart';
import 'chat_user_profile_dialog.dart';

/// A group's members: avatar, name, account and role, the owner marked and
/// first; role tabs above narrow it to one role.
class ChatMemberList extends ConsumerStatefulWidget {
  const ChatMemberList({
    super.key,
    required this.chat,
    required this.users,
    this.ownerAccount,
  });

  final ChatThreadKey chat;
  final Map<int, ChatUser> users;
  final String? ownerAccount;

  @override
  ConsumerState<ChatMemberList> createState() => _ChatMemberListState();
}

class _ChatMemberListState extends ConsumerState<ChatMemberList> {
  /// The role tab shown; null for everyone.
  String? _role;

  Map<int, ChatUser> get users => widget.users;
  ChatThreadKey get chat => widget.chat;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final roleNames =
        ref.watch(chatRoleNamesProvider(chat.accountId)).value ?? const {};
    // One height for every row (a medium avatar and its padding).
    final rowHeight = s.xl6 * 0.9 + s.sm * 2;
    return switch (ref.watch(chatMembersProvider(chat))) {
      AsyncData(value: Ok(:final value)) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // On the header's colour and as tall as the pinned-message bar
          // beside it, its bottom border included; none for a single role.
          if (const OrderChatRoles()([for (final id in value) users[id]?.role])
                  .length >
              1)
            Container(
              height: kChatSubHeaderHeight,
              padding: EdgeInsets.symmetric(horizontal: s.xl),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(bottom: context.hairlineSide),
              ),
              child: ChatRoleTabs(
                serverNames: roleNames,
                roles: [for (final id in value) users[id]?.role],
                selected: _role,
                onSelect: (role) => setState(() => _role = role),
              ),
            ),
          // The list scrolls on its own under the tabs: a shorter tab does
          // not move anything above it.
          Expanded(
            child: Builder(
              builder: (context) {
                final shown = [
                  for (final id in _ownerFirst(value))
                    if (chatRoleMatches(_role, users[id]?.role)) id,
                ];
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(s.xl, s.sm, s.xl, s.sm),
                  itemExtent: rowHeight,
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _MemberRow(
                    chat: chat,
                    users: users,
                    id: shown[i],
                    owner: _isOwner(shown[i]),
                    roleNames: roleNames,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      AsyncData(value: Err()) ||
      AsyncError() => AppInlineNote(text: l.chatMembersFailed, isError: true),
      _ => const AppInlineSpinner(),
    };
  }

  bool _isOwner(int id) {
    final owner = widget.ownerAccount;
    return owner != null && users[id]?.account == owner;
  }

  List<int> _ownerFirst(List<int> ids) => [
    ...ids.where(_isOwner),
    ...ids.where((id) => !_isOwner(id)),
  ];
}

/// A member: avatar, name, account and role; a tap opens their profile.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.chat,
    required this.users,
    required this.id,
    required this.owner,
    required this.roleNames,
  });

  final ChatThreadKey chat;
  final Map<int, ChatUser> users;
  final int id;
  final bool owner;
  final Map<String, String> roleNames;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    return InkWell(
      borderRadius: BorderRadius.circular(context.radii.md),
      onTap: () => ChatUserProfileDialog.show(
        context,
        accountId: chat.accountId,
        userId: id,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: s.sm, horizontal: s.xs),
        child: Row(
          children: [
            ChatAvatar(
              name: chatUserName(context, users, id),
              imageUrl: chatAvatarUrl(users, id),
              presence: chatPresenceOf(users, id),
              verified: chatVerifiedBadge(context, users, id),
            ),
            SizedBox(width: s.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatUserName(context, users, id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodyStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  if (users[id]?.account case final account?)
                    Text(
                      [
                        '@$account',
                        if (users[id]?.role case final role?
                            when role.trim().isNotEmpty)
                          chatRoleLabel(context, role, serverNames: roleNames),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (owner) TintedPill(color: c.accent, label: l.chatOwner),
          ],
        ),
      ),
    );
  }
}

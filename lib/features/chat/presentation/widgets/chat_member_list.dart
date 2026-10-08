import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_user_profile_dialog.dart';

/// A group's members: avatar, name and account, the owner marked and first.
class ChatMemberList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    return switch (ref.watch(chatMembersProvider(chat))) {
      AsyncData(value: Ok(:final value)) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in _ownerFirst(value))
            InkWell(
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
                              '@$account',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.caption.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_isOwner(id))
                      TintedPill(color: c.accent, label: l.chatOwner),
                  ],
                ),
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
    final owner = ownerAccount;
    return owner != null && users[id]?.account == owner;
  }

  List<int> _ownerFirst(List<int> ids) => [
    ...ids.where(_isOwner),
    ...ids.where((id) => !_isOwner(id)),
  ];
}

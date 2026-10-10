import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';

/// A ZenTao person as chat knows them: their photo with presence and the
/// "verified" check, and a tap that opens the one-to-one chat with them.
/// Someone chat doesn't know (yet) is drawn the same, without the tap.
class ChatPersonChip extends ConsumerWidget {
  const ChatPersonChip({
    super.key,
    required this.accountId,
    required this.name,
    required this.avatarSize,
  });

  final String accountId;

  /// Display name or login handle: tickets carry either.
  final String name;
  final double avatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final users =
        ref.watch(chatUsersProvider(accountId)).value ??
        const <int, ChatUser>{};
    final user = _find(users.values, name);
    final shown = user?.realname.isNotEmpty == true ? user!.realname : name;
    final chip = HoverSurface(
      onTap: user == null
          ? null
          : () {
              // The detail slide-over would stay on top of the chat.
              ref.read(openTicketIdProvider.notifier).close();
              openDirectChatWith(
                context,
                ref,
                accountId: accountId,
                userId: user.userId,
              );
            },
      padding: EdgeInsets.fromLTRB(s.xxs, s.xxs, s.md, s.xxs),
      borderRadius: BorderRadius.circular(context.radii.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAvatar(
            name: shown,
            imageUrl: user?.avatarUrl,
            diameter: avatarSize,
            presence: chatPresenceOf(users, user?.userId),
            verified: chatVerifiedBadge(context, users, user?.userId),
          ),
          SizedBox(width: s.sm),
          Text(
            shown,
            style: context.typography.secondary.copyWith(color: c.textPrimary),
          ),
        ],
      ),
    );
    return user == null
        ? chip
        : Tooltip(
            message: AppL10n.of(context).chatWithPerson(shown),
            waitDuration: const Duration(milliseconds: 400),
            child: chip,
          );
  }
}

/// Just the photo of a ZenTao person as chat knows them, with no tap — for a
/// spot that is itself tappable (a board card). Someone chat doesn't know is
/// drawn as their initial.
class ChatPersonAvatar extends ConsumerWidget {
  const ChatPersonAvatar({
    super.key,
    required this.accountId,
    required this.name,
    required this.diameter,
  });

  final String accountId;

  /// Display name or login handle: tickets carry either.
  final String name;
  final double diameter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users =
        ref.watch(chatUsersProvider(accountId)).value ??
        const <int, ChatUser>{};
    final user = _find(users.values, name);
    return ChatAvatar(
      name: user?.realname.isNotEmpty == true ? user!.realname : name,
      imageUrl: user?.avatarUrl,
      diameter: diameter,
    );
  }
}

/// The chat user [name] refers to: by login handle first (unique), then by
/// display name.
ChatUser? _find(Iterable<ChatUser> users, String name) {
  final key = name.trim().toLowerCase();
  if (key.isEmpty) return null;
  ChatUser? byName;
  for (final u in users) {
    if (u.deleted) continue;
    if (u.account.toLowerCase() == key) return u;
    if (byName == null && u.realname.trim().toLowerCase() == key) byName = u;
  }
  return byName;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'mention_autocomplete.dart';

/// Suggestions while an `@name` is being typed: the chat's members (and
/// "@all" in groups) matching it. Tap or Enter/Tab inserts one.
class ChatMentionList extends ConsumerWidget {
  const ChatMentionList({
    super.key,
    required this.thread,
    required this.mentions,
    required this.onPick,
  });

  final ChatThreadKey thread;
  final MentionAutocomplete mentions;
  final void Function(MentionCandidate candidate) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = mentions.query;
    if (query == null) {
      mentions.visible = const [];
      return const SizedBox.shrink();
    }
    final users = ref.watch(chatUsersProvider(thread.accountId)).value ?? {};
    final self = ref.watch(chatSelfUserIdProvider(thread.accountId)).value;
    final chat = ref
        .watch(chatConversationsProvider(thread.accountId))
        .value
        ?.where((c) => c.gid == thread.chatGid)
        .firstOrNull;
    final group = chat != null && chat.type != ChatType.one2one;
    final ids = switch (chat) {
      ChatConversation(type: ChatType.one2one, :final peerUserId?) => [
        peerUserId,
      ],
      _ when group => switch (ref.watch(chatMembersProvider(thread)).value) {
        Ok(:final value) => value,
        _ => const <int>[],
      },
      _ => const <int>[],
    };
    final all = <MentionCandidate>[
      if (group) (userId: null, name: 'all', account: null),
      for (final id in ids)
        if (id != self)
          (
            userId: id,
            name: chatUserName(context, users, id),
            account: users[id]?.account,
          ),
    ];
    final visible = MentionAutocomplete.filter(all, query);
    mentions.visible = visible;
    if (visible.isEmpty) return const SizedBox.shrink();

    final c = context.colors;
    return Material(
      color: c.surface,
      elevation: 8,
      shadowColor: c.scrim.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(context.radii.lg),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(context.radii.lg),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.spacing.xl6 * 8),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
            children: [
              for (final (i, candidate) in visible.indexed)
                _Row(
                  candidate: candidate,
                  users: users,
                  highlighted: i == mentions.highlight,
                  onHover: () => mentions.highlightAt(i),
                  onTap: () => onPick(candidate),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One suggestion: a large avatar and the name; "@all" gets an accent @
/// disc and "Notify everyone · @All".
class _Row extends StatelessWidget {
  const _Row({
    required this.candidate,
    required this.users,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final MentionCandidate candidate;
  final Map<int, ChatUser> users;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final everyone = candidate.userId == null;
    final avatarSize = s.xl6;
    final name = context.typography.body.copyWith(color: c.textPrimary);
    return Material(
      color: highlighted ? c.selectionFill : Colors.transparent,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        onHover: (inside) {
          if (inside) onHover();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.xl3, vertical: s.md),
          child: Row(
            children: [
              if (everyone)
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.atSign300,
                    color: c.onAccent,
                    size: s.xl5,
                  ),
                )
              else
                ChatAvatar(
                  name: candidate.name,
                  imageUrl: chatAvatarUrl(users, candidate.userId),
                  verified: chatVerifiedBadge(context, users, candidate.userId),
                  diameter: avatarSize,
                ),
              SizedBox(width: s.xl),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: everyone
                        ? [
                            TextSpan(text: AppL10n.of(context).chatMentionAll),
                            TextSpan(
                              text: '  ·  @All',
                              style: name.copyWith(color: c.accent),
                            ),
                          ]
                        : [TextSpan(text: candidate.name)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: name,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

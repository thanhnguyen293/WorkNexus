import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_person_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_profile_section.dart';

/// The groups the signed-in user shares with [person]; a tap opens one.
/// Hidden when they share none.
class ChatProfileGroups extends ConsumerWidget {
  const ChatProfileGroups({super.key, required this.person});

  final ChatPersonKey person;

  /// Rows shown before "+N more".
  static const _shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final fetch = ref.watch(chatSharedGroupsProvider(person));
    final groups = switch (fetch.value) {
      Ok(:final value) => value,
      _ => null,
    };
    if (groups != null && groups.isEmpty) return const SizedBox.shrink();
    return ChatProfileSection(
      title: l.chatProfileSharedGroups,
      count: groups?.length,
      children: switch (fetch.value) {
        Ok() when groups != null => [
          ChatProfileExpandableRows(
            shown: _shown,
            rows: [
              for (final g in groups)
                _GroupRow(accountId: person.accountId, group: g),
            ],
          ),
        ],
        Err() => [ChatProfileNote(l.chatProfileLoadFailed, isError: true)],
        _ when fetch.hasError => [
          ChatProfileNote(l.chatProfileLoadFailed, isError: true),
        ],
        _ => const [ChatProfileLoadingRows(rows: 1)],
      },
    );
  }
}

class _GroupRow extends ConsumerWidget {
  const _GroupRow({required this.accountId, required this.group});

  final String accountId;
  final ChatConversation group;

  void _open(BuildContext context, WidgetRef ref) {
    ref.read(appNavProvider.notifier).selectChat();
    ref.read(pickedChatAccountProvider.notifier).state = accountId;
    ref.read(selectedChatGidProvider(accountId).notifier).state = group.gid;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final users = ref.watch(chatUsersProvider(accountId)).value ?? const {};
    final avatar = chatAvatarStyle(group, users);
    return HoverSurface(
      onTap: () => _open(context, ref),
      semanticLabel: AppL10n.of(context).chatProfileOpenGroup(group.name),
      padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.sm),
      child: Row(
        children: [
          ChatAvatar(
            name: group.name,
            imageUrl: avatar.imageUrl,
            label: avatar.label,
            background: avatar.background,
            icon: avatar.icon,
            diameter: s.xl5 + s.xs,
          ),
          SizedBox(width: s.lg),
          Expanded(
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.body.copyWith(color: c.textPrimary),
            ),
          ),
          Icon(
            LucideIcons.chevronRight300,
            size: context.sizes.iconMd,
            color: c.textTertiary,
          ),
        ],
      ),
    );
  }
}

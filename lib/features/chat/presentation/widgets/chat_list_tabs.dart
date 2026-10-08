import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_list_tab.dart';
import '../providers/chat_providers.dart';

/// Filter chips above the chat list: all, direct, groups, bots.
class ChatListTabs extends ConsumerWidget {
  const ChatListTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final current = ref.watch(chatListTabProvider);
    final labels = {
      ChatListTab.all: l.chatTabAll,
      ChatListTab.direct: l.chatTabDirect,
      ChatListTab.groups: l.chatTabGroups,
      ChatListTab.bots: l.chatTabBots,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
      child: Row(
        children: [
          for (final tab in ChatListTab.values) ...[
            _TabChip(
              label: labels[tab] ?? '',
              selected: tab == current,
              onTap: () => ref.read(chatListTabProvider.notifier).state = tab,
            ),
            SizedBox(width: context.spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.lg,
          vertical: context.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
        child: Text(
          label,
          style: context.typography.secondary.copyWith(
            color: selected ? c.accent : c.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

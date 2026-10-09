import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_list_tab.dart';
import '../providers/chat_providers.dart';
import 'chat_tab_chip.dart';

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
            ChatTabChip(
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

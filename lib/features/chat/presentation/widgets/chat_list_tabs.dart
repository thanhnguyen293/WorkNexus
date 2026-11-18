import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_list_tab.dart';
import '../providers/chat_providers.dart';
import 'chat_list_filter_button.dart';
import 'chat_tab_chip.dart';

/// Above the chat list: filter chips — all, direct, groups, bots, each with
/// the unread count of the chats it shows — and, on the right, the filter
/// by status and category tags.
class ChatListTabs extends ConsumerWidget {
  const ChatListTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final current = ref.watch(chatListTabProvider);
    final labels = {
      ChatListTab.all: l.chatTabAll,
      ChatListTab.direct: l.chatTabDirect,
      ChatListTab.groups: l.chatTabGroups,
      ChatListTab.bots: l.chatTabBots,
    };
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: s.lg),
            child: Row(
              children: [
                for (final tab in ChatListTab.values) ...[
                  ChatTabChip(
                    label: labels[tab] ?? '',
                    selected: tab == current,
                    unread: ref.watch(chatTabUnreadProvider(tab)),
                    onTap: () =>
                        ref.read(chatListTabProvider.notifier).state = tab,
                  ),
                  SizedBox(width: s.sm),
                ],
              ],
            ),
          ),
        ),
        // A hairline keeps the scrolled-under tabs from running into it.
        Container(
          width: context.borders.hairline,
          height: context.sizes.iconMd,
          margin: EdgeInsets.symmetric(horizontal: s.sm),
          color: context.colors.border,
        ),
        Padding(
          padding: EdgeInsets.only(right: s.lg),
          child: const ChatListFilterButton(),
        ),
      ],
    );
  }
}

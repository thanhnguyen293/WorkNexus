import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_search_period.dart';
import '../providers/chat_search_providers.dart';

/// The search's time range — "Any time", "Past 7 days", … — as a small
/// button that picks another from a menu. Shared by every search of the
/// account.
class ChatSearchPeriodButton extends ConsumerWidget {
  const ChatSearchPeriodButton({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final period = ref.watch(chatSearchPeriodProvider(accountId));
    return Tooltip(
      message: l.chatSearchPeriod,
      child: Builder(
        builder: (button) => AppButton.textNeutral(
          size: AppButtonSize.extraSmall,
          icon: LucideIcons.calendarClock300,
          onPressed: () async {
            final box = button.findRenderObject() as RenderBox?;
            if (box == null) return;
            final picked = await showAppContextMenu(
              button,
              at: box.localToGlobal(box.size.bottomLeft(Offset.zero)),
              entries: [
                for (final p in ChatSearchPeriod.values)
                  AppMenuEntry(
                    icon: p == ChatSearchPeriod.all
                        ? LucideIcons.infinity300
                        : LucideIcons.calendar300,
                    label: chatSearchPeriodLabel(l, p),
                    checked: p == period,
                  ),
              ],
            );
            if (picked == null) return;
            ref.read(chatSearchPeriodProvider(accountId).notifier).state =
                ChatSearchPeriod.values[picked];
          },
          child: Text(chatSearchPeriodLabel(l, period)),
        ),
      ),
    );
  }
}

/// The name of [period] in menus and on its button.
String chatSearchPeriodLabel(AppL10n l, ChatSearchPeriod period) =>
    switch (period) {
      ChatSearchPeriod.all => l.chatSearchPeriodAll,
      ChatSearchPeriod.week => l.chatSearchPeriodWeek,
      ChatSearchPeriod.month => l.chatSearchPeriodMonth,
      ChatSearchPeriod.quarter => l.chatSearchPeriodQuarter,
      ChatSearchPeriod.year => l.chatSearchPeriodYear,
    };

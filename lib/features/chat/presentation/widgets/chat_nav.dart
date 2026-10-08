import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'unread_badge.dart';

/// Sidebar entry that opens the chat view, with the total unread count.
/// Also keeps every ZenTao account logged into chat so the count is live.
class ChatNav extends ConsumerWidget {
  const ChatNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatAutoConnectProvider);
    if (ref.watch(chatAccountsProvider).isEmpty) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    final c = context.colors;
    final active =
        ref.watch(chatOpenProvider) && !ref.watch(integrationsVisibleProvider);
    final unread = ref.watch(chatUnreadTotalProvider);
    return Container(
      decoration: BoxDecoration(border: Border(top: context.hairlineSide)),
      padding: EdgeInsets.all(context.spacing.md),
      child: InkWell(
        onTap: () => active ? showBoardView(ref) : showChatView(ref),
        borderRadius: BorderRadius.circular(context.radii.md),
        child: Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
          decoration: BoxDecoration(
            color: active ? c.selectionFill : Colors.transparent,
            borderRadius: BorderRadius.circular(context.radii.md),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: context.spacing.xl2,
                color: c.textSecondary,
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Text(
                  l.chat,
                  style: context.typography.secondary.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
              if (unread > 0) UnreadBadge(count: unread),
            ],
          ),
        ),
      ),
    );
  }
}

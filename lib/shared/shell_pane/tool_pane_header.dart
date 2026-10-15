import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/di/providers.dart';
import '../../core/domain/entities/account.dart';
import '../../core/domain/value_objects/account_sync_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/util/relative_time.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/badges.dart';
import '../../l10n/app_localizations.dart';

/// The header of a tool navigation pane (L3/L4): provider badge, account name,
/// sync freshness dot + label, and an optional ↗ external link button.
class ToolPaneHeader extends ConsumerWidget {
  const ToolPaneHeader({
    super.key,
    required this.account,
    this.onWebUrlTap,
    this.syncStatusOverride,
    this.trailing,
  });

  final Account account;
  final VoidCallback? onWebUrlTap;
  final AccountSyncStatus? syncStatusOverride;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Minute ticker keeps relative timestamps fresh (design §6 / S8.1)
    ref.watch(syncTickerProvider);

    final status =
        syncStatusOverride ??
        ref.watch(syncStatusProvider(account.id)).value ??
        const AccountSyncStatus.idle();

    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    final dotColor = _dotColor(c, status);
    final statusText = _statusText(context, l, status);
    final displayName = account.handle;

    return Container(
      height: context.sizes.titleBarHeight,
      padding: EdgeInsets.symmetric(horizontal: s.md),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          ProviderBadge(account.providerType, big: true),
          SizedBox(width: s.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.titleSm.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: s.xxs),
                Row(
                  children: [
                    Container(
                      key: const Key('tool_pane_header_sync_dot'),
                      width: context.sizes.iconXs / 2,
                      height: context.sizes.iconXs / 2,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: s.xs),
                    Expanded(
                      child: Text(
                        statusText,
                        key: const Key('tool_pane_header_sync_text'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ?trailing,
          if (onWebUrlTap != null)
            AppIconButton(
              icon: LucideIcons.externalLink300,
              tooltip: l.openInBrowser,
              size: AppIconButtonSize.small,
              onPressed: onWebUrlTap,
            ),
        ],
      ),
    );
  }

  static Color _dotColor(AppColors c, AccountSyncStatus status) {
    return status.when(
      idle: (_) => c.success,
      syncing: () => c.accent,
      offline: () => c.textTertiary,
      authExpired: () => c.warning,
      error: (_) => c.warning,
    );
  }

  static String _statusText(
    BuildContext context,
    AppL10n l,
    AccountSyncStatus status,
  ) {
    return status.when(
      idle: (lastSyncedAt) {
        if (lastSyncedAt == null) return l.syncNotSyncedYet;
        return l.syncSynced(formatWhen(context, lastSyncedAt));
      },
      syncing: () => l.syncSyncing,
      offline: () => l.syncOffline,
      authExpired: () => l.syncAuthExpired,
      error: (_) => l.syncFailed,
    );
  }
}

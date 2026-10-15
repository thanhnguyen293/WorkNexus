import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/account_sync_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/tools/tool_registry_provider.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';

/// One connected account row on the Integrations page (design §5, specs S6.2).
/// Displays provider badge, provider name, `Account: {handle} · {capabilities}`,
/// a health pill from [AccountSyncStatus], and a Manage action.
class IntegrationRow extends ConsumerWidget {
  const IntegrationRow({
    super.key,
    required this.account,
    this.syncStatusOverride,
    this.onManage,
  });

  final Account account;
  final AccountSyncStatus? syncStatusOverride;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final registry = ref.watch(toolRegistryProvider);
    final module = registry[account.providerType];

    final status =
        syncStatusOverride ??
        ref.watch(syncStatusProvider(account.id)).asData?.value ??
        const AccountSyncStatus.idle();

    final capabilities =
        module?.sections
            .where((sec) => sec.available)
            .map((sec) => sec.label(l))
            .join(', ') ??
        '';

    final capabilitiesText = capabilities.isNotEmpty
        ? l.accountCapabilitiesPrefix(account.handle, capabilities)
        : account.handle;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.lg),
      child: Row(
        children: [
          ProviderBadge(account.providerType, big: true),
          SizedBox(width: s.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.providerType.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                SizedBox(height: s.xxs),
                Text(
                  capabilitiesText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.captionSm.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: s.md),
          _HealthPill(status: status),
          SizedBox(width: s.lg),
          AppButton.outlinedNeutral(
            onPressed: onManage,
            child: Text(l.accountManage),
          ),
        ],
      ),
    );
  }
}

class _HealthPill extends StatelessWidget {
  const _HealthPill({required this.status});

  final AccountSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);

    final (label, color) = switch (status) {
      SyncIdle() || SyncRunning() => (l.healthConnected, c.success),
      SyncAuthExpired() => (l.healthAuthExpired, c.warning),
      SyncOffline() => (l.healthOffline, c.textTertiary),
      SyncError() => (l.healthError, c.error),
    };

    return TintedPill(label: label, color: color);
  }
}

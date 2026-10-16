import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/dashboard_providers.dart';

/// When the account's dashboard was last fetched, and refresh — which
/// fetches the dashboard and the assigned work again.
class DashboardSyncStatus extends ConsumerWidget {
  const DashboardSyncStatus({
    super.key,
    required this.account,
    required this.fetchedAt,
  });

  final Account account;
  final DateTime? fetchedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final format = ref.watch(appSettingsProvider.select((s) => s.dateFormat));
    final refreshing =
        ref.watch(dashboardRefreshProvider(account.id)).isLoading ||
        ref.watch(myWorkSyncProvider(account.id)).isLoading;
    final fetchedAt = this.fetchedAt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fetchedAt != null) ...[
          Flexible(
            child: Text(
              l.dashboardUpdated(
                formatWhen(context, fetchedAt, format: format),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
          ),
          SizedBox(width: context.spacing.xs),
        ],
        AppIconButton(
          icon: LucideIcons.rotateCw300,
          tooltip: l.refresh,
          isLoading: refreshing,
          onPressed: () {
            ref.read(dashboardRefreshProvider(account.id).notifier).refresh();
            ref.read(myWorkSyncProvider(account.id).notifier).refresh();
          },
        ),
      ],
    );
  }
}

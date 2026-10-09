import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_dashboard.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_account_picker.dart';

/// Today's date over the last update, beside the account picker and
/// refresh.
class DashboardHeadlineStatus extends ConsumerWidget {
  const DashboardHeadlineStatus({
    super.key,
    required this.account,
    required this.dashboard,
  });

  final Account account;
  final ZenTaoDashboard? dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final l = AppL10n.of(context);
    final format = ref.watch(appSettingsProvider.select((s) => s.dateFormat));
    final refreshing =
        ref.watch(dashboardRefreshProvider(account.id)).isLoading ||
        ref.watch(myWorkSyncProvider(account.id)).isLoading;
    final locale = Localizations.localeOf(context).toString();
    final fetchedAt = dashboard?.fetchedAt;
    return Row(
      children: [
        const DashboardAccountPicker(),
        SizedBox(width: s.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat.MMMMEEEEd(locale).format(DateTime.now()),
              style: t.bodySmStrong.copyWith(color: c.textSecondary),
            ),
            if (fetchedAt != null)
              Text(
                l.dashboardUpdated(
                  formatWhen(context, fetchedAt, format: format),
                ),
                style: t.caption.copyWith(color: c.textTertiary),
              ),
          ],
        ),
        SizedBox(width: s.sm),
        IconButton(
          tooltip: l.refresh,
          onPressed: refreshing
              ? null
              : () {
                  ref
                      .read(dashboardRefreshProvider(account.id).notifier)
                      .refresh();
                  ref.read(myWorkSyncProvider(account.id).notifier).refresh();
                },
          icon: refreshing
              ? SizedBox.square(
                  dimension: s.xl3,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(PhosphorIconsLight.arrowClockwise, color: c.textSecondary),
        ),
      ],
    );
  }
}

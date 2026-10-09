import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/dashboard_providers.dart';

/// Switches between ZenTao accounts; hidden with only one.
class DashboardAccountPicker extends ConsumerWidget {
  const DashboardAccountPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(dashboardAccountsProvider);
    final current = ref.watch(dashboardAccountProvider);
    if (accounts.length < 2 || current == null) return const SizedBox.shrink();
    final c = context.colors;
    return Tooltip(
      message: AppL10n.of(context).dashboardAccount,
      child: DropdownButton<String>(
        mouseCursor: WidgetStateMouseCursor.clickable,
        value: current.id,
        underline: const SizedBox.shrink(),
        style: context.typography.bodySm.copyWith(color: c.textPrimary),
        items: [
          for (final a in accounts)
            DropdownMenuItem(
              value: a.id,
              child: Text(
                '${a.handle} · ${Uri.tryParse(a.baseUrl ?? '')?.host ?? ''}',
              ),
            ),
        ],
        onChanged: (id) =>
            ref.read(dashboardPickedAccountIdProvider.notifier).state = id,
      ),
    );
  }
}

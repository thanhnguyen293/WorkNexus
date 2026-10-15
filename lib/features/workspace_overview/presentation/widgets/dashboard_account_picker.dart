import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_dropdown.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/dashboard_providers.dart';

/// Switches between ZenTao accounts; hidden with only one.
class DashboardAccountPicker extends ConsumerWidget {
  const DashboardAccountPicker({super.key});

  /// AppDropdown fills its width, so the header gives it a fixed one; long
  /// "handle · host" labels ellipsize inside it.
  static const double _width = 220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(dashboardAccountsProvider);
    final current = ref.watch(dashboardAccountProvider);
    if (accounts.length < 2 || current == null) return const SizedBox.shrink();
    final labels = {
      for (final a in accounts)
        a.id: '${a.handle} · ${Uri.tryParse(a.baseUrl ?? '')?.host ?? ''}',
    };
    return SizedBox(
      width: _width,
      child: AppDropdown<String>(
        value: current.id,
        values: labels.keys.toList(),
        labelOf: (id) => labels[id] ?? id,
        tooltip: AppL10n.of(context).dashboardAccount,
        onChanged: (id) =>
            ref.read(dashboardPickedAccountIdProvider.notifier).state = id,
      ),
    );
  }
}

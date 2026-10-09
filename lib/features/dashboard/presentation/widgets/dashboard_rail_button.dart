import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/widgets/app_rail_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/dashboard_providers.dart';

/// The dashboard destination of the app rail; shown once a ZenTao account is
/// connected.
class DashboardRailButton extends ConsumerWidget {
  const DashboardRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dashboardAccountsProvider).isEmpty) {
      return const SizedBox.shrink();
    }
    return AppRailButton(
      icon: PhosphorIconsLight.squaresFour,
      selectedIcon: PhosphorIconsFill.squaresFour,
      label: AppL10n.of(context).dashboard,
      selected:
          ref.watch(mainViewProvider) == MainView.dashboard &&
          !ref.watch(integrationsVisibleProvider),
      onTap: () => showMainView(ref, MainView.dashboard),
    );
  }
}

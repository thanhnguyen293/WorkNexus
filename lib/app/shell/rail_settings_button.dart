import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/widgets/app_rail_button.dart';
import '../../l10n/app_localizations.dart';

/// The rail's Settings place: the app's settings and connected accounts.
class RailSettingsButton extends ConsumerWidget {
  const RailSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(appNavProvider.select((n) => n.rail is SettingsTarget)) &&
        !ref.watch(miniAppOnScreenProvider);
    return AppRailButton(
      key: const ValueKey('rail-settings-button'),
      icon: LucideIcons.settings300,
      label: AppL10n.of(context).settings,
      selected: selected,
      onTap: () => ref.read(appNavProvider.notifier).selectSettings(),
    );
  }
}

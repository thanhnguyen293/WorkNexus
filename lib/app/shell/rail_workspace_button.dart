import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/widgets/app_rail_labeled_button.dart';
import '../../l10n/app_localizations.dart';

/// The top workspace button in the navigation rail (design §8, specs S3.1).
/// Selects the workspace-level view (Overview, Integrations, Members, Settings).
class RailWorkspaceButton extends ConsumerWidget {
  const RailWorkspaceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final nav = ref.watch(appNavProvider);

    final isSelected =
        nav.rail is WorkspaceTarget && !ref.watch(miniAppOnScreenProvider);

    return AppRailLabeledButton(
      key: const ValueKey('rail-workspace-button'),
      leading: const Icon(LucideIcons.layoutGrid300),
      label: l.workspace,
      selected: isSelected,
      onTap: () => ref
          .read(appNavProvider.notifier)
          .selectWorkspaceSection(WorkspaceSection.overview),
    );
  }
}

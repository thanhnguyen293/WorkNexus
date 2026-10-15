import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hover_surface.dart';
import '../../features/connections/presentation/widgets/create_workspace_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Footer action buttons for the workspace switcher popover.
class WorkspaceSwitcherFooter extends ConsumerWidget {
  const WorkspaceSwitcherFooter({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    return Padding(
      padding: EdgeInsets.all(s.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HoverSurface(
            onTap: () {
              onClose();
              CreateWorkspaceDialog.show(context);
            },
            borderRadius: BorderRadius.circular(context.radii.sm),
            padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
            child: Row(
              children: [
                Icon(
                  LucideIcons.plus300,
                  size: context.sizes.iconSm,
                  color: c.textSecondary,
                ),
                SizedBox(width: s.sm),
                Text(
                  l.createWorkspace,
                  style: context.typography.bodySm.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          HoverSurface(
            onTap: () {
              onClose();
              ref
                  .read(appNavProvider.notifier)
                  .selectWorkspaceSection(WorkspaceSection.settings);
            },
            borderRadius: BorderRadius.circular(context.radii.sm),
            padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
            child: Row(
              children: [
                Icon(
                  LucideIcons.settings300,
                  size: context.sizes.iconSm,
                  color: c.textSecondary,
                ),
                SizedBox(width: s.sm),
                Text(
                  l.settings,
                  style: context.typography.bodySm.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

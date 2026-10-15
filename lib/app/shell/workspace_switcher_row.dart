import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/domain/entities/account.dart';
import '../../core/domain/entities/workspace.dart';
import '../../core/domain/value_objects/provider_type.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hover_surface.dart';
import '../../core/widgets/workspace_badge.dart';
import '../../l10n/app_localizations.dart';

/// Single selectable row inside [WorkspaceSwitcherPopover].
class WorkspaceSwitcherRow extends StatelessWidget {
  const WorkspaceSwitcherRow({
    super.key,
    required this.workspace,
    required this.subtitle,
    required this.isSelected,
    required this.isHighlighted,
    required this.onTap,
  });

  final Workspace workspace;
  final String subtitle;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;

  /// Builds the subtitle string listing connected tools or empty message.
  static String formatToolsSubtitle(
    List<Account> accounts,
    String workspaceId,
    AppL10n l,
  ) {
    final wsAccounts = accounts
        .where((a) => a.workspaceId == workspaceId)
        .toList();
    if (wsAccounts.isEmpty) return l.noConnectedAccounts;

    final toolOrder = [
      ProviderType.zentao,
      ProviderType.github,
      ProviderType.gitlab,
    ];
    final presentTools = <String>[];

    for (final pt in toolOrder) {
      if (wsAccounts.any((a) => a.providerType == pt)) {
        presentTools.add(pt.displayName);
      }
    }

    return presentTools.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;
    final l = AppL10n.of(context);

    return HoverSurface(
      onTap: onTap,
      selected: isHighlighted || isSelected,
      borderRadius: BorderRadius.circular(r.sm),
      color: (isHighlighted || isSelected)
          ? c.selectionFill
          : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
      child: Row(
        children: [
          WorkspaceBadge(
            Color(workspace.colorValue),
            workspace.shortCode,
            iconKey: workspace.iconKey,
          ),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  workspace.isPersonal ? l.personal : workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodySmStrong.copyWith(
                    color: isSelected ? c.accent : c.textPrimary,
                  ),
                ),
                SizedBox(height: s.xxs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.captionSm.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected) ...[
            SizedBox(width: s.sm),
            Icon(LucideIcons.check300, size: 14, color: c.accent),
          ],
        ],
      ),
    );
  }
}

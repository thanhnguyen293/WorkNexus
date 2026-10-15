import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/domain/entities/workspace.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hover_surface.dart';
import '../../core/widgets/workspace_badge.dart';

/// The clickable workspace trigger button inside [WorkspaceBreadcrumb].
class WorkspaceBreadcrumbTrigger extends StatelessWidget {
  const WorkspaceBreadcrumbTrigger({
    super.key,
    required this.workspace,
    required this.isOpen,
    required this.onTap,
  });

  final Workspace workspace;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;

    return HoverSurface(
      key: const ValueKey('workspace-switcher-trigger'),
      onTap: onTap,
      selected: isOpen,
      borderRadius: BorderRadius.circular(r.sm),
      color: isOpen ? c.selectionFill : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
      height: context.sizes.controlSm,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WorkspaceBadge(
            Color(workspace.colorValue),
            workspace.shortCode,
            iconKey: workspace.iconKey,
          ),
          SizedBox(width: s.sm),
          Text(
            workspace.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.bodySmStrong.copyWith(
              color: c.textPrimary,
            ),
          ),
          SizedBox(width: s.xs),
          Icon(
            LucideIcons.chevronDown300,
            size: context.sizes.iconXs,
            color: c.textSecondary,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hover_surface.dart';
import '../../l10n/app_localizations.dart';
import 'sidebar_primitives.dart';
import 'sidebar_tree_rows.dart';

/// A quick scope row at the top of the scope list (e.g. "All projects",
/// "Assigned to me", "Review requested").
class ScopeQuickRow extends StatelessWidget {
  const ScopeQuickRow({
    super.key,
    required this.label,
    this.icon,
    this.count,
    this.selected = false,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final ink = selected ? c.accent : c.textPrimary;

    return HoverSurface(
      onTap: onTap,
      selected: selected,
      borderRadius: BorderRadius.circular(context.radii.sm),
      color: selected ? c.selectionFill : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
      height: context.sizes.controlSm,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: context.sizes.iconSm,
              color: selected ? c.accent : c.textTertiary,
            ),
            SizedBox(width: s.sm),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodySm.copyWith(
                color: ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (count != null) ...[
            SizedBox(width: s.xs),
            Text(
              '$count',
              style: context.typography.monoXs.copyWith(
                color: selected ? c.accent : c.textTertiary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section header for grouped scopes (PINNED, ALL PROJECTS, RECENT, etc.).
class ScopeGroupHeader extends StatelessWidget {
  const ScopeGroupHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: context.sizes.controlSm,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: sidebarGroupLabelStyle(context),
      ),
    );
  }
}

/// A scope item row (project, product, repository, library, conversation).
/// Shows a color dot or icon, name, optional path/group subtitle, open item count,
/// and optional pin toggle button.
class ScopeRow extends StatelessWidget {
  const ScopeRow({
    super.key,
    required this.name,
    this.path,
    this.color,
    this.icon,
    this.count,
    this.selected = false,
    this.isPinned = false,
    this.onPinToggle,
    required this.onTap,
  });

  final String name;
  final String? path;
  final Color? color;
  final IconData? icon;
  final int? count;
  final bool selected;
  final bool isPinned;
  final VoidCallback? onPinToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final ink = selected ? c.accent : c.textPrimary;
    final onPin = onPinToggle;

    final Widget leading;
    final scopeColor = color;
    if (scopeColor != null) {
      leading = Container(
        width: context.sizes.iconXs / 2,
        height: context.sizes.iconXs / 2,
        decoration: BoxDecoration(color: scopeColor, shape: BoxShape.circle),
      );
    } else {
      leading = Icon(
        icon ?? LucideIcons.folder300,
        size: context.sizes.iconSm,
        color: selected ? c.accent : c.textTertiary,
      );
    }

    final pathText = path;

    return HoverSurface(
      onTap: onTap,
      selected: selected,
      borderRadius: BorderRadius.circular(context.radii.sm),
      color: selected ? c.selectionFill : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
      height: pathText != null ? null : context.sizes.controlSm,
      child: Row(
        children: [
          leading,
          SizedBox(width: s.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodySm.copyWith(
                    color: ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (pathText != null && pathText.isNotEmpty)
                  Text(
                    pathText.startsWith('/') ? pathText : '/ $pathText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.captionSm.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          if (count != null) ...[
            SizedBox(width: s.xs),
            Text(
              '$count',
              style: context.typography.monoXs.copyWith(
                color: selected ? c.accent : c.textTertiary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
          if (onPin != null) ...[
            SizedBox(width: s.xs),
            SidebarPinButton(
              pinned: isPinned,
              onTap: onPin,
              tooltip: isPinned ? l.unpinProject : l.pinProject,
            ),
          ],
        ],
      ),
    );
  }
}

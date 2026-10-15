import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_count_badge.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../l10n/app_localizations.dart';
import 'sidebar_tree_rows.dart';

/// One indentation level of the sources tree: a left guide rail with the child
/// inset beside it. [strong] uses the heavier border for top-level branches.
class SidebarTreeBranch extends StatelessWidget {
  const SidebarTreeBranch({
    super.key,
    required this.child,
    this.strong = false,
  });

  final Widget child;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        left: context.spacing.md,
        top: context.spacing.xxs,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: strong ? c.borderStrong : c.border),
          ),
        ),
        padding: EdgeInsets.only(left: context.spacing.md),
        child: child,
      ),
    );
  }
}

/// A pin/unpin toggle for a pinnable sidebar row (products, executions,
/// projects, repos).
class SidebarPinButton extends StatelessWidget {
  const SidebarPinButton({
    super.key,
    required this.pinned,
    required this.onTap,
    required this.tooltip,
  });

  final bool pinned;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // No resting fill: a column of pinned rows would turn into a stack of
    // tinted squares. The accent glyph alone marks a pin.
    return AppIconButton(
      icon: pinned ? LucideIcons.pin500 : LucideIcons.pin300,
      tooltip: tooltip,
      size: AppIconButtonSize.small,
      color: pinned ? c.accent : c.textTertiary,
      onPressed: onTap,
    );
  }
}

/// Compact progress glyph for sidebar rows that are actively refreshing.
class SidebarSyncIndicator extends StatelessWidget {
  const SidebarSyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: 21,
      child: Center(
        child: SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            valueColor: AlwaysStoppedAnimation<Color>(c.accent),
          ),
        ),
      ),
    );
  }
}

/// Non-tappable label marking a per-account "Pinned" area at the top of a
/// source node (ZenTao / GitLab / GitHub). It carries no count: each pinned
/// row shows its own.
class SidebarPinnedHeader extends StatelessWidget {
  const SidebarPinnedHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Container(
      height: context.sizes.controlSm,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Row(
        children: [
          Icon(LucideIcons.pin500, size: context.sizes.iconXs, color: c.accent),
          SizedBox(width: context.spacing.xs),
          Expanded(
            child: Text(
              l.pinned,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sidebarGroupLabelStyle(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A sources-tree node's count of open tickets assigned to me; nothing at
/// zero, so only nodes with work stand out.
class SidebarCountBadge extends StatelessWidget {
  const SidebarCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Tooltip(
      message: AppL10n.of(context).assignedToMe,
      child: AppCountBadge(count),
    );
  }
}

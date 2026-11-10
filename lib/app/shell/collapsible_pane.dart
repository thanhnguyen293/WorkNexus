import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation/collapsed_panes.dart';
import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hover_surface.dart';
import '../../l10n/app_localizations.dart';

/// A navigation pane the reader can fold away with its own collapse button
/// (see [collapsedPanesProvider]): folded, a thin strip beside the rail
/// names the place and opens the pane again on a click.
///
/// The pane stays mounted while folded (offstage), so it keeps its scroll
/// position and state.
class CollapsiblePane extends ConsumerWidget {
  const CollapsiblePane({
    super.key,
    required this.paneKey,
    required this.icon,
    required this.label,
    required this.child,
  });

  final String paneKey;

  /// What the folded strip shows, as a rail button does: the pane's place.
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(
      collapsedPanesProvider.select((keys) => keys.contains(paneKey)),
    );
    return Stack(
      children: [
        Offstage(offstage: collapsed, child: child),
        if (collapsed)
          _Strip(
            icon: icon,
            label: label,
            onExpand: () =>
                ref.read(collapsedPanesProvider.notifier).expand(paneKey),
          ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.label,
    required this.onExpand,
  });

  final IconData icon;
  final String label;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final sizes = context.sizes;
    // As wide as the rail, read like one of its buttons.
    return Container(
      width: sizes.railWidth,
      height: double.infinity,
      padding: EdgeInsets.fromLTRB(s.xs, s.md, s.xs, 0),
      alignment: Alignment.topCenter,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: context.hairlineSide),
      ),
      child: Tooltip(
        message: AppL10n.of(context).paneExpand,
        child: HoverSurface(
          onTap: onExpand,
          borderRadius: BorderRadius.circular(context.radii.sm),
          padding: EdgeInsets.symmetric(vertical: s.sm),
          width: double.infinity,
          child: Column(
            children: [
              Icon(icon, size: sizes.iconLg, color: c.textSecondary),
              SizedBox(height: s.xs),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.typography.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: s.sm),
              Icon(
                LucideIcons.panelLeftOpen300,
                size: sizes.iconSm,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

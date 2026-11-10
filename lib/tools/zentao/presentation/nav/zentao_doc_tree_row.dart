import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../shared/shell_pane/sidebar_primitives.dart';

/// One row of the Docs tree: a library (with a chevron, [expanded] non-null)
/// or a document ([indented] under its library). The pin shows while the row
/// is hovered, and stays for a pinned row, so 150 libraries don't each carry
/// a pin glyph.
class ZenTaoDocTreeRow extends StatefulWidget {
  const ZenTaoDocTreeRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.pinned,
    required this.pinTooltip,
    required this.onPin,
    this.subtitle,
    this.expanded,
    this.indented = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool pinned;
  final String pinTooltip;
  final VoidCallback onPin;

  /// A library's open state; null for a document (no chevron).
  final bool? expanded;
  final bool indented;
  final bool selected;

  @override
  State<ZenTaoDocTreeRow> createState() => _ZenTaoDocTreeRowState();
}

class _ZenTaoDocTreeRowState extends State<ZenTaoDocTreeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final sizes = context.sizes;
    final selected = widget.selected;
    final ink = selected ? c.accent : c.textPrimary;
    final expanded = widget.expanded;
    final subtitle = widget.subtitle;
    // A document lines up under its library's icon, past the chevron.
    final indent = widget.indented ? sizes.iconSm + s.xs : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: HoverSurface(
        onTap: widget.onTap,
        selected: selected,
        color: selected ? c.selectionFill : Colors.transparent,
        borderRadius: BorderRadius.circular(context.radii.sm),
        padding: EdgeInsets.fromLTRB(s.sm + indent, s.xxs, s.xs, s.xxs),
        constraints: BoxConstraints(minHeight: sizes.controlSm),
        child: Row(
          children: [
            if (expanded != null) ...[
              Icon(
                expanded
                    ? LucideIcons.chevronDown300
                    : LucideIcons.chevronRight300,
                size: sizes.iconSm,
                color: c.textTertiary,
              ),
              SizedBox(width: s.xs),
            ],
            Icon(
              widget.icon,
              size: sizes.iconSm,
              color: selected ? c.accent : c.textTertiary,
            ),
            SizedBox(width: s.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySm.copyWith(
                      color: ink,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
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
            // Room kept for the pin, so the label doesn't reflow on hover.
            Visibility.maintain(
              visible: _hovered || widget.pinned,
              child: SidebarPinButton(
                pinned: widget.pinned,
                onTap: widget.onPin,
                tooltip: widget.pinTooltip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

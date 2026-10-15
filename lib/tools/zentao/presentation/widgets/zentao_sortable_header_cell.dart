import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';

/// Interactive sortable column header cell for ZenTao task & bug tables.
///
/// Displays uppercase column label, subtle sort state arrow (↑/↓), and
/// handles click-to-sort toggles matching the design system.
class ZenTaoSortableHeaderCell extends StatelessWidget {
  const ZenTaoSortableHeaderCell({
    super.key,
    required this.label,
    this.field,
    required this.currentSort,
    this.onSort,
    this.width,
    this.flex,
  }) : assert(
         width != null || flex != null,
         'Either width or flex must be provided',
       );

  final String label;
  final TicketSortField? field;
  final TicketSort currentSort;
  final ValueChanged<TicketSortField>? onSort;
  final double? width;
  final int? flex;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final isSortable = field != null && onSort != null;
    final isActive = isSortable && currentSort.field == field;

    final textColor = isActive ? c.textPrimary : c.textSecondary;
    final textStyle = context.typography.caption.copyWith(
      color: textColor,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
      letterSpacing: 0.3,
    );

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
        if (isSortable) ...[
          SizedBox(width: s.xxs),
          Icon(
            isActive
                ? (currentSort.descending
                      ? LucideIcons.arrowDown300
                      : LucideIcons.arrowUp300)
                : LucideIcons.chevronsUpDown300,
            size: context.sizes.iconXs,
            color: isActive
                ? c.textPrimary
                : c.textTertiary.withValues(alpha: 0.5),
          ),
        ],
      ],
    );

    if (isSortable) {
      content = HoverSurface(
        onTap: () => onSort!(field!),
        borderRadius: BorderRadius.circular(context.radii.xs),
        hoverColor: c.surfaceSubtle,
        tintOnHover: false,
        padding: EdgeInsets.symmetric(horizontal: s.xxs, vertical: 2),
        child: content,
      );
    }

    if (flex != null) {
      return Expanded(flex: flex!, child: content);
    }
    return SizedBox(width: width!, child: content);
  }
}

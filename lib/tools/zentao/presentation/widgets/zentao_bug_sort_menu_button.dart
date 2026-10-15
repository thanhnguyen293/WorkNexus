import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Quick sort dropdown menu button for the ZenTao bug table.
class ZenTaoBugSortMenuButton extends StatelessWidget {
  const ZenTaoBugSortMenuButton({
    super.key,
    required this.currentSort,
    required this.onSort,
  });

  final TicketSort currentSort;
  final ValueChanged<TicketSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    final fieldLabel = switch (currentSort.field) {
      TicketSortField.id => l.tableColumnId,
      TicketSortField.title => l.tableColumnTitle,
      TicketSortField.severity => l.severity,
      TicketSortField.priority => l.priority,
      TicketSortField.status => l.status,
      TicketSortField.assignee => l.assignedTo,
      TicketSortField.resolution => l.resolution,
      _ => l.tableColumnId,
    };

    return PopupMenuButton<TicketSortField>(
      tooltip: '',
      onSelected: onSort,
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.sm),
        side: BorderSide(color: c.border),
      ),
      itemBuilder: (context) => [
        _buildItem(context, TicketSortField.id, l.tableColumnId),
        _buildItem(context, TicketSortField.severity, l.severity),
        _buildItem(context, TicketSortField.priority, l.priority),
        _buildItem(context, TicketSortField.status, l.status),
        _buildItem(context, TicketSortField.title, l.tableColumnTitle),
        _buildItem(context, TicketSortField.assignee, l.assignedTo),
        _buildItem(context, TicketSortField.resolution, l.resolution),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.xs),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentSort.descending
                  ? LucideIcons.arrowDownWideNarrow300
                  : LucideIcons.arrowUpNarrowWide300,
              size: 13,
              color: c.textSecondary,
            ),
            SizedBox(width: s.xxs),
            Text(
              fieldLabel,
              style: context.typography.caption.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<TicketSortField> _buildItem(
    BuildContext context,
    TicketSortField field,
    String label,
  ) {
    final c = context.colors;
    final isSelected = currentSort.field == field;
    return PopupMenuItem<TicketSortField>(
      value: field,
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.typography.bodySm.copyWith(
                color: isSelected ? c.accent : c.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              currentSort.descending
                  ? LucideIcons.arrowDown300
                  : LucideIcons.arrowUp300,
              size: 14,
              color: c.accent,
            ),
        ],
      ),
    );
  }
}

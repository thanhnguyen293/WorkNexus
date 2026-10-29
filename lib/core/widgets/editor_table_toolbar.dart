import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Top action toolbar for embedded editor tables: shows dimensions (R × C),
/// add/remove row/col buttons, and delete table action.
class EditorTableToolbar extends StatelessWidget {
  const EditorTableToolbar({
    super.key,
    required this.rowCount,
    required this.colCount,
    required this.onAddRow,
    required this.onAddColumn,
    required this.onRemoveRow,
    required this.onRemoveColumn,
    required this.onDeleteTable,
  });

  final int rowCount;
  final int colCount;
  final VoidCallback onAddRow;
  final VoidCallback onAddColumn;
  final VoidCallback onRemoveRow;
  final VoidCallback onRemoveColumn;
  final VoidCallback onDeleteTable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xxs),
      color: c.surfaceSubtle,
      child: Row(
        children: [
          Icon(LucideIcons.table300, size: s.sm, color: c.textTertiary),
          SizedBox(width: s.xxs),
          Text(
            '$rowCount × $colCount',
            style: context.typography.monoSm.copyWith(color: c.textTertiary),
          ),
          const Spacer(),
          TableActionButton(
            tooltip: l.addRow,
            icon: LucideIcons.plus300,
            label: l.addRow,
            onTap: onAddRow,
          ),
          SizedBox(width: s.xxs),
          TableActionButton(
            tooltip: l.addColumn,
            icon: LucideIcons.plus300,
            label: l.addColumn,
            onTap: onAddColumn,
          ),
          if (rowCount > 1) ...[
            SizedBox(width: s.xxs),
            TableActionButton(
              tooltip: l.removeRow,
              icon: LucideIcons.minus300,
              onTap: onRemoveRow,
            ),
          ],
          if (colCount > 1) ...[
            SizedBox(width: s.xxs),
            TableActionButton(
              tooltip: l.removeColumn,
              icon: LucideIcons.minus300,
              onTap: onRemoveColumn,
            ),
          ],
          SizedBox(width: s.xs),
          TableActionButton(
            tooltip: l.deleteTable,
            icon: LucideIcons.trash2300,
            color: c.error,
            onTap: onDeleteTable,
          ),
        ],
      ),
    );
  }
}

/// A compact icon-and-label button used in table toolbar.
class TableActionButton extends StatelessWidget {
  const TableActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.label,
    this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final textColor = color ?? c.textSecondary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.xs),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: s.sm, color: textColor),
              if (label case final text?) ...[
                SizedBox(width: s.xxs),
                Text(
                  text,
                  style: context.typography.caption.copyWith(color: textColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

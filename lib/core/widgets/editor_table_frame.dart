import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'editor_table_cell.dart';

/// Renders a formatted visual table inside Flutter Quill with borders,
/// headers, cell editing, and row/column control buttons.
class EditorTableFrame extends StatefulWidget {
  const EditorTableFrame({
    super.key,
    required this.rows,
    required this.readOnly,
    required this.onChanged,
    required this.onDelete,
  });

  final List<List<String>> rows;
  final bool readOnly;
  final ValueChanged<List<List<String>>> onChanged;
  final VoidCallback onDelete;

  @override
  State<EditorTableFrame> createState() => _EditorTableFrameState();
}

class _EditorTableFrameState extends State<EditorTableFrame> {
  late List<List<String>> _data;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _data = widget.rows.map(List<String>.from).toList();
    if (_data.isEmpty) {
      _data = [
        ['Header 1', 'Header 2'],
        ['Value 1', 'Value 2'],
      ];
    }
  }

  @override
  void didUpdateWidget(covariant EditorTableFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows != oldWidget.rows) {
      _data = widget.rows.map(List<String>.from).toList();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _notifyChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      widget.onChanged(_data);
    });
  }

  void _onCellChanged(int row, int col, String val) {
    if (row < _data.length && col < _data[row].length) {
      _data[row][col] = val;
      _notifyChanged();
    }
  }

  void _addRow() {
    final colCount = _data.isNotEmpty ? _data.first.length : 2;
    setState(() {
      _data.add(List<String>.filled(colCount, ''));
    });
    widget.onChanged(_data);
  }

  void _removeRow() {
    if (_data.length <= 1) return;
    setState(() {
      _data.removeLast();
    });
    widget.onChanged(_data);
  }

  void _addColumn() {
    setState(() {
      for (var r = 0; r < _data.length; r++) {
        _data[r].add(r == 0 ? 'Header ${_data[r].length + 1}' : '');
      }
    });
    widget.onChanged(_data);
  }

  void _removeColumn() {
    if (_data.isEmpty || _data.first.length <= 1) return;
    setState(() {
      for (var r = 0; r < _data.length; r++) {
        _data[r].removeLast();
      }
    });
    widget.onChanged(_data);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final colCount = _data.isNotEmpty ? _data.first.length : 0;
    final rowCount = _data.length;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.sm),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(context.radii.md),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.readOnly)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: s.sm,
                  vertical: s.xxs,
                ),
                color: c.surfaceSubtle,
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.table300,
                      size: s.md,
                      color: c.textTertiary,
                    ),
                    SizedBox(width: s.xs),
                    Text(
                      '$rowCount × $colCount',
                      style: context.typography.monoSm.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    _TableActionButton(
                      tooltip: l.addRow,
                      icon: LucideIcons.plus300,
                      label: l.addRow,
                      onTap: _addRow,
                    ),
                    SizedBox(width: s.xxs),
                    _TableActionButton(
                      tooltip: l.addColumn,
                      icon: LucideIcons.plus300,
                      label: l.addColumn,
                      onTap: _addColumn,
                    ),
                    if (rowCount > 1) ...[
                      SizedBox(width: s.xxs),
                      _TableActionButton(
                        tooltip: l.removeRow,
                        icon: LucideIcons.minus300,
                        onTap: _removeRow,
                      ),
                    ],
                    if (colCount > 1) ...[
                      SizedBox(width: s.xxs),
                      _TableActionButton(
                        tooltip: l.removeColumn,
                        icon: LucideIcons.minus300,
                        onTap: _removeColumn,
                      ),
                    ],
                    SizedBox(width: s.xs),
                    _TableActionButton(
                      tooltip: l.deleteTable,
                      icon: LucideIcons.trash2300,
                      color: c.error,
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ),
            if (!widget.readOnly) Divider(height: 1, color: c.border),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var r = 0; r < _data.length; r++)
                      TableRowWidget(
                        row: _data[r],
                        rowIndex: r,
                        isHeader: r == 0,
                        readOnly: widget.readOnly,
                        onCellChanged: (col, val) =>
                            _onCellChanged(r, col, val),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({
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

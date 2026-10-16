import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Renders a single row in an embedded editor table.
class TableRowWidget extends StatelessWidget {
  const TableRowWidget({
    super.key,
    required this.row,
    required this.rowIndex,
    required this.isHeader,
    required this.readOnly,
    required this.onCellChanged,
  });

  final List<String> row;
  final int rowIndex;
  final bool isHeader;
  final bool readOnly;
  final void Function(int col, String val) onCellChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isHeader ? c.surfaceSubtle : c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var col = 0; col < row.length; col++)
            TableCellWidget(
              initialText: row[col],
              isHeader: isHeader,
              readOnly: readOnly,
              isLastCol: col == row.length - 1,
              onChanged: (val) => onCellChanged(col, val),
            ),
        ],
      ),
    );
  }
}

/// Renders an individual editable or read-only cell in an embedded editor table.
class TableCellWidget extends StatefulWidget {
  const TableCellWidget({
    super.key,
    required this.initialText,
    required this.isHeader,
    required this.readOnly,
    required this.isLastCol,
    required this.onChanged,
  });

  final String initialText;
  final bool isHeader;
  final bool readOnly;
  final bool isLastCol;
  final ValueChanged<String> onChanged;

  @override
  State<TableCellWidget> createState() => _TableCellWidgetState();
}

class _TableCellWidgetState extends State<TableCellWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant TableCellWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final textStyle = (widget.isHeader
            ? context.typography.bodyStrong.copyWith(
                fontWeight: FontWeight.w600,
              )
            : context.typography.body)
        .copyWith(color: c.textPrimary, fontSize: 13);

    return Container(
      width: 140,
      constraints: const BoxConstraints(minHeight: 36),
      decoration: BoxDecoration(
        border: widget.isLastCol
            ? null
            : Border(right: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xxs),
      alignment: Alignment.centerLeft,
      child: widget.readOnly
          ? Text(widget.initialText, style: textStyle)
          : TextFormField(
              controller: _controller,
              style: textStyle,
              maxLines: null,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onChanged,
            ),
    );
  }
}

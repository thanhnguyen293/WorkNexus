import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../theme/app_colors.dart';
import 'editor_table_cell.dart';

/// Renders a single row in an embedded editor table.
class TableRowWidget extends StatelessWidget {
  const TableRowWidget({
    super.key,
    required this.row,
    required this.rowIndex,
    required this.isHeader,
    required this.readOnly,
    required this.columnWidths,
    this.focusNodes,
    this.onNextCell,
    this.onPreviousCell,
    this.quillController,
    required this.onCellChanged,
  });

  final List<String> row;
  final int rowIndex;
  final bool isHeader;
  final bool readOnly;
  final List<double> columnWidths;
  final List<FocusNode?>? focusNodes;
  final void Function(int col)? onNextCell;
  final void Function(int col)? onPreviousCell;
  final QuillController? quillController;
  final void Function(int col, String val) onCellChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isHeader ? c.surfaceSubtle : c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var col = 0; col < row.length; col++)
              TableCellWidget(
                initialText: row[col],
                isHeader: isHeader,
                readOnly: readOnly,
                isLastCol: col == row.length - 1,
                width: col < columnWidths.length ? columnWidths[col] : 120.0,
                focusNode: col < (focusNodes?.length ?? 0)
                    ? focusNodes![col]
                    : null,
                onNextCell: onNextCell == null ? null : () => onNextCell!(col),
                onPreviousCell: onPreviousCell == null
                    ? null
                    : () => onPreviousCell!(col),
                quillController: quillController,
                onChanged: (val) => onCellChanged(col, val),
              ),
          ],
        ),
      ),
    );
  }
}

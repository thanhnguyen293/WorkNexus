import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'editor_table_cell.dart';
import 'editor_table_toolbar.dart';

/// Computes adaptive, proportional column widths based on cell text length.
List<double> computeColumnWidths(List<List<String>> data) {
  if (data.isEmpty) return const [];
  final colCount = data.first.length;
  final widths = <double>[];
  for (var col = 0; col < colCount; col++) {
    var maxLen = 0;
    for (final row in data) {
      if (col < row.length && row[col].length > maxLen) {
        maxLen = row[col].length;
      }
    }
    if (maxLen <= 7) {
      widths.add(78.0);
    } else if (maxLen <= 12) {
      widths.add(110.0);
    } else if (maxLen <= 22) {
      widths.add(160.0);
    } else {
      widths.add(360.0);
    }
  }
  return widths;
}

/// Renders a formatted visual table matching ZenTao web's clean table format
/// with adaptive column widths, direct cell editing, smooth cursor moving,
/// Tab navigation between cells, and row/column actions.
class EditorTableFrame extends StatefulWidget {
  const EditorTableFrame({
    super.key,
    this.tableId,
    required this.rows,
    required this.readOnly,
    this.quillController,
    this.onDataChanged,
    required this.onStructureChanged,
    required this.onDelete,
  });

  final String? tableId;
  final List<List<String>> rows;
  final bool readOnly;
  final QuillController? quillController;
  final ValueChanged<List<List<String>>>? onDataChanged;
  final ValueChanged<List<List<String>>> onStructureChanged;
  final VoidCallback onDelete;

  @override
  State<EditorTableFrame> createState() => _EditorTableFrameState();
}

class _EditorTableFrameState extends State<EditorTableFrame> {
  late List<List<String>> _data;
  final Map<String, FocusNode> _focusNodes = {};

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
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }

  FocusNode _getFocusNode(int row, int col) {
    final key = '$row:$col';
    return _focusNodes.putIfAbsent(
      key,
      () => FocusNode(
        debugLabel: 'table_cell_${widget.tableId}_$key',
        onKeyEvent: (node, event) => _handleCellKeyEvent(row, col, event),
      ),
    );
  }

  KeyEventResult _handleCellKeyEvent(int row, int col, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      _navigateTab(row, col, isShift: isShift);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _navigateTab(int row, int col, {required bool isShift}) {
    final rowCount = _data.length;
    final colCount = _data.isNotEmpty ? _data.first.length : 0;
    if (rowCount == 0 || colCount == 0) return;

    if (isShift) {
      var prevR = row;
      var prevC = col - 1;
      if (prevC < 0) {
        prevR = row - 1;
        prevC = colCount - 1;
      }
      if (prevR >= 0) {
        _focusCell(prevR, prevC);
      }
    } else {
      var nextR = row;
      var nextC = col + 1;
      if (nextC >= colCount) {
        nextR = row + 1;
        nextC = 0;
      }
      if (nextR < rowCount) {
        _focusCell(nextR, nextC);
      } else if (!widget.readOnly) {
        _addRow();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusCell(nextR, 0);
        });
      }
    }
  }

  void _focusCell(int r, int c) {
    widget.quillController?.skipRequestKeyboard = true;
    _getFocusNode(r, c).requestFocus();
  }

  void _onCellChanged(int row, int col, String val) {
    if (row < _data.length && col < _data[row].length) {
      _data[row][col] = val;
      widget.onDataChanged?.call(_data);
    }
  }

  void _addRow() {
    final colCount = _data.isNotEmpty ? _data.first.length : 2;
    setState(() {
      _data.add(List<String>.filled(colCount, ''));
    });
    widget.onStructureChanged(_data);
  }

  void _removeRow() {
    if (_data.length <= 1) return;
    setState(() {
      _data.removeLast();
    });
    widget.onStructureChanged(_data);
  }

  void _addColumn() {
    setState(() {
      for (var r = 0; r < _data.length; r++) {
        _data[r].add(r == 0 ? 'Header ${_data[r].length + 1}' : '');
      }
    });
    widget.onStructureChanged(_data);
  }

  void _removeColumn() {
    if (_data.isEmpty || _data.first.length <= 1) return;
    setState(() {
      for (var r = 0; r < _data.length; r++) {
        _data[r].removeLast();
      }
    });
    widget.onStructureChanged(_data);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final colWidths = computeColumnWidths(_data);
    final rowCount = _data.length;
    final colCount = _data.isNotEmpty ? _data.first.length : 0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.readOnly)
              EditorTableToolbar(
                rowCount: rowCount,
                colCount: colCount,
                onAddRow: _addRow,
                onAddColumn: _addColumn,
                onRemoveRow: _removeRow,
                onRemoveColumn: _removeColumn,
                onDeleteTable: widget.onDelete,
              ),
            if (!widget.readOnly) Divider(height: 1, color: c.border),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var r = 0; r < _data.length; r++)
                    TableRowWidget(
                      row: _data[r],
                      rowIndex: r,
                      isHeader: r == 0,
                      readOnly: widget.readOnly,
                      columnWidths: colWidths,
                      focusNodes: [
                        for (var col = 0; col < _data[r].length; col++)
                          _getFocusNode(r, col),
                      ],
                      onNextCell: (col) =>
                          _navigateTab(r, col, isShift: false),
                      onPreviousCell: (col) =>
                          _navigateTab(r, col, isShift: true),
                      quillController: widget.quillController,
                      onCellChanged: (col, val) =>
                          _onCellChanged(r, col, val),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'editor_table_frame.dart';

/// In-memory store for active table data so typing inside table cells
/// updates instantly without triggering destructive Quill document replacement.
class TableDataStore {
  final Map<String, List<List<String>>> _tables = {};
  final Map<String, List<List<String>>> _initial = {};

  void registerInitial(String id, List<List<String>> rows) {
    _initial[id] = rows.map(List<String>.from).toList();
    _tables[id] = rows.map(List<String>.from).toList();
  }

  void set(String id, List<List<String>> rows) {
    _tables[id] = rows.map(List<String>.from).toList();
  }

  List<List<String>>? get(String id) => _tables[id];

  bool hasChanges(String id) {
    final current = _tables[id];
    final init = _initial[id];
    if (current == null || init == null) return false;
    if (current.length != init.length) return true;
    for (var r = 0; r < current.length; r++) {
      if (current[r].length != init[r].length) return true;
      for (var c = 0; c < current[r].length; c++) {
        if (current[r][c] != init[r][c]) return true;
      }
    }
    return false;
  }

  bool get hasAnyChanges => _tables.keys.any(hasChanges);

  void remove(String id) {
    _tables.remove(id);
    _initial.remove(id);
  }

  void clear() {
    _tables.clear();
    _initial.clear();
  }
}

/// InheritedWidget that provides a [TableDataStore] to descending embed builders.
class TableDataStoreScope extends InheritedWidget {
  const TableDataStoreScope({
    super.key,
    required this.store,
    required super.child,
  });

  final TableDataStore store;

  static TableDataStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TableDataStoreScope>()?.store;

  @override
  bool updateShouldNotify(TableDataStoreScope oldWidget) =>
      store != oldWidget.store;
}

/// Embeds an interactive, formatted table inside Flutter Quill with borders,
/// headers, cell editing, and row/column actions.
class EditorTableEmbedBuilder extends EmbedBuilder {
  const EditorTableEmbedBuilder([this.tableStore]);

  final TableDataStore? tableStore;

  static const String tableType = 'table';

  @override
  String get key => tableType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final rawData = embedContext.node.value.data;
    final parsedId = parseTableId(rawData);
    final tableId =
        parsedId ??
        'table_${embedContext.node.documentOffset}_${embedContext.node.hashCode}';
    final store = tableStore ?? TableDataStoreScope.maybeOf(context);
    final storedRows = store?.get(tableId);
    final rows = storedRows ?? parseTableRows(rawData);
    if (storedRows == null && rows.isNotEmpty) {
      store?.set(tableId, rows);
    }

    return EditorTableFrame(
      tableId: tableId,
      rows: rows.isEmpty
          ? const [
              ['', '', ''],
              ['', '', ''],
            ]
          : rows,
      readOnly: embedContext.readOnly,
      quillController: embedContext.controller,
      onDataChanged: (updatedRows) {
        store?.set(tableId, updatedRows);
      },
      onStructureChanged: (updatedRows) {
        store?.set(tableId, updatedRows);
        final node = embedContext.node;
        embedContext.controller.replaceText(
          node.documentOffset,
          1,
          BlockEmbed(
            tableType,
            jsonEncode({'id': tableId, 'rows': updatedRows}),
          ),
          null,
        );
      },
      onDelete: () {
        store?.remove(tableId);
        final node = embedContext.node;
        embedContext.controller.replaceText(node.documentOffset, 1, '', null);
      },
    );
  }
}

/// Parses table ID from either a JSON map or string.
String? parseTableId(dynamic data) {
  if (data is Map) {
    final id = data['id'];
    if (id is String && id.isNotEmpty) return id;
  } else if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['id'] is String) {
        return decoded['id'] as String;
      }
    } catch (_) {}
  }
  return null;
}

/// Parses table rows from either a JSON map or string.
List<List<String>> parseTableRows(dynamic data) {
  if (data is Map) {
    final rawRows = data['rows'];
    if (rawRows is List) {
      return rawRows
          .map((r) => (r as List).map((c) => c?.toString() ?? '').toList())
          .toList();
    }
  } else if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['rows'] is List) {
        return (decoded['rows'] as List)
            .map((r) => (r as List).map((c) => c?.toString() ?? '').toList())
            .toList();
      } else if (decoded is List) {
        return decoded
            .map((r) => (r as List).map((c) => c?.toString() ?? '').toList())
            .toList();
      }
    } catch (_) {}
  }
  return const [];
}

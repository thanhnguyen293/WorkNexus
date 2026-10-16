import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'editor_table_frame.dart';

/// Embeds an interactive, formatted table inside Flutter Quill with borders,
/// headers, cell editing, and row/column actions.
class EditorTableEmbedBuilder extends EmbedBuilder {
  const EditorTableEmbedBuilder();

  static const String tableType = 'table';

  @override
  String get key => tableType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final rows = parseTableRows(embedContext.node.value.data);
    return EditorTableFrame(
      rows: rows.isEmpty
          ? const [
              ['Header 1', 'Header 2', 'Header 3'],
              ['Value 1', 'Value 2', 'Value 3'],
            ]
          : rows,
      readOnly: embedContext.readOnly,
      onChanged: (updatedRows) {
        final node = embedContext.node;
        embedContext.controller.replaceText(
          node.documentOffset,
          1,
          BlockEmbed(tableType, jsonEncode({'rows': updatedRows})),
          null,
        );
      },
      onDelete: () {
        final node = embedContext.node;
        embedContext.controller.replaceText(
          node.documentOffset,
          1,
          '',
          null,
        );
      },
    );
  }
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

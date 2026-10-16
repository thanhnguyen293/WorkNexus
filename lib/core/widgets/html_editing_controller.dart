// Quill marks its clipboard options experimental; pasting images and rich
// text depends on them.
// ignore_for_file: experimental_member_use

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import 'editor_table_embed.dart';

/// Holds rich text being edited, read from and written back as HTML — the
/// format ZenTao's own editor stores descriptions in.
class HtmlEditingController {
  HtmlEditingController({String html = ''}) : _initialHtml = html {
    quill = QuillController(
      document: _document(html),
      selection: const TextSelection.collapsed(offset: 0),
      config: QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(
          enableExternalRichPaste: true,
          onImagePaste: (bytes) async => onImagePaste?.call(bytes),
        ),
      ),
    );
    _initialDelta = quill.document.toDelta();
  }

  final String _initialHtml;
  late final Delta _initialDelta;
  late final QuillController quill;

  /// Turns a pasted image into the URL to show it at (by uploading it); a
  /// pasted image is dropped while this is null or gives null.
  Future<String?> Function(Uint8List bytes)? onImagePaste;

  /// The text as HTML; empty when nothing but whitespace was written.
  String get html {
    if (quill.document.toPlainText().trim().isEmpty &&
        !_hasEmbeds(quill.document.toDelta())) {
      return '';
    }
    if (quill.document.toDelta() == _initialDelta &&
        _initialHtml.contains('<table')) {
      return _initialHtml;
    }
    final converter = QuillDeltaToHtmlConverter(
      _withImageWidths(quill.document.toDelta()),
      ConverterOptions(
        converterOptions: OpConverterOptions(
          inlineStylesFlag: true,
          linkTarget: '',
        ),
      ),
    );
    converter.renderCustomWith = (customOp, contextOp) {
      if (customOp.insert.type == EditorTableEmbedBuilder.tableType) {
        final rows = parseTableRows(customOp.insert.value);
        if (rows.isNotEmpty) {
          return _buildTableHtml(rows);
        }
      }
      return '';
    };
    final raw = converter.convert();
    return _restoreTables(raw);
  }

  void dispose() => quill.dispose();
}

Document _document(String html) {
  final source = html.trim();
  if (source.isEmpty) return Document();
  final extracted = _extractTables(_widthsAsStyle(source));
  final delta = HtmlToDelta().convert(extracted.html);
  final replaced = _replaceTablePlaceholders(delta, extracted.tables);
  // A document must end with a line break.
  if (replaced.isEmpty ||
      !(replaced.last.data is String &&
          (replaced.last.data! as String).endsWith('\n'))) {
    replaced.insert('\n');
  }
  return Document.fromDelta(replaced);
}

({String html, List<List<List<String>>> tables}) _extractTables(String html) {
  final doc = html_parser.parseFragment(html);
  final tables = doc.querySelectorAll('table');
  if (tables.isEmpty) return (html: html, tables: const []);

  final tableList = <List<List<String>>>[];
  for (final table in tables) {
    final rows = <List<String>>[];
    for (final tr in table.querySelectorAll('tr')) {
      final cells = tr.querySelectorAll('th, td');
      if (cells.isEmpty) continue;
      rows.add(cells.map((c) => c.text.trim()).toList());
    }
    if (rows.isNotEmpty) {
      final maxCols =
          rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      for (var i = 0; i < rows.length; i++) {
        while (rows[i].length < maxCols) {
          rows[i].add('');
        }
      }
      final idx = tableList.length;
      tableList.add(rows);
      table.replaceWith(
        html_parser.parseFragment('<p>WORKNEXUS_TABLE_$idx</p>'),
      );
    }
  }
  return (html: doc.outerHtml, tables: tableList);
}

Delta _replaceTablePlaceholders(
  Delta delta,
  List<List<List<String>>> tables,
) {
  if (tables.isEmpty) return delta;
  final newDelta = Delta();
  for (final op in delta.toList()) {
    if (op.data is String) {
      final text = op.data as String;
      final regex = RegExp(r'WORKNEXUS_TABLE_(\d+)');
      final matches = regex.allMatches(text);
      if (matches.isEmpty) {
        newDelta.insert(op.data, op.attributes);
      } else {
        var lastEnd = 0;
        for (final m in matches) {
          if (m.start > lastEnd) {
            newDelta.insert(text.substring(lastEnd, m.start), op.attributes);
          }
          final idx = int.tryParse(m.group(1) ?? '');
          if (idx != null && idx < tables.length) {
            newDelta.insert({
              EditorTableEmbedBuilder.tableType:
                  jsonEncode({'rows': tables[idx]}),
            });
          }
          lastEnd = m.end;
        }
        if (lastEnd < text.length) {
          newDelta.insert(text.substring(lastEnd), op.attributes);
        }
      }
    } else {
      newDelta.insert(op.data, op.attributes);
    }
  }
  return newDelta;
}

/// Restores markdown table rows back to clean HTML `<table>` elements.
String _restoreTables(String html) {
  if (!html.contains('|')) return html;
  final doc = html_parser.parseFragment(html);
  _processContainer(doc);
  for (final container in doc.querySelectorAll('div, section, article')) {
    _processContainer(container);
  }
  return doc.outerHtml;
}

void _processContainer(dom.Node container) {
  if (container.nodes.isEmpty) return;
  final hasCandidate = container.nodes.any(
    (n) =>
        n is dom.Element &&
        (n.localName == 'p' || n.localName == 'div') &&
        n.innerHtml.contains('|'),
  );
  if (!hasCandidate) return;

  final newNodes = _processNodes(container.nodes);
  container.nodes.clear();
  container.nodes.addAll(newNodes);
}

List<dom.Node> _processNodes(List<dom.Node> nodes) {
  final result = <dom.Node>[];
  final pendingTableRows = <List<String>>[];

  void flushTable() {
    if (pendingTableRows.isEmpty) return;
    final rows = List<List<String>>.from(pendingTableRows);
    pendingTableRows.clear();

    final hasMultipleCols = rows.any((r) => r.length >= 2);
    if ((rows.length >= 2 || (rows.length == 1 && rows.first.length >= 2)) &&
        hasMultipleCols) {
      final tableHtml = _buildTableHtml(rows);
      result.addAll(html_parser.parseFragment(tableHtml).nodes);
    } else {
      for (final r in rows) {
        final p = html_parser.parseFragment('<p>| ${r.join(' | ')} |</p>');
        result.addAll(p.nodes);
      }
    }
  }

  for (final node in nodes) {
    if (node is dom.Element &&
        (node.localName == 'p' || node.localName == 'div')) {
      final inner = node.innerHtml;
      if (!inner.contains('|')) {
        flushTable();
        result.add(node);
        continue;
      }

      final lines = inner.split(RegExp(r'<br\s*/?>|\n'));
      final beforeLines = <String>[];
      final currentTableLines = <List<String>>[];
      final afterLines = <String>[];
      var inTable = false;

      for (final line in lines) {
        final trimmed = line.trim();
        if (_isTableRow(trimmed)) {
          final cells = _extractCells(trimmed);
          if (_isSeparatorRow(cells)) {
            inTable = true;
          } else {
            inTable = true;
            currentTableLines.add(cells);
          }
        } else if (!inTable) {
          if (trimmed.isNotEmpty) beforeLines.add(line);
        } else {
          if (trimmed.isNotEmpty) afterLines.add(line);
        }
      }

      if (beforeLines.isNotEmpty) {
        flushTable();
        final p = html_parser.parseFragment(
          '<p>${beforeLines.join('<br>')}</p>',
        );
        result.addAll(p.nodes);
      }

      if (currentTableLines.isNotEmpty) {
        pendingTableRows.addAll(currentTableLines);
      }

      if (afterLines.isNotEmpty) {
        flushTable();
        final p = html_parser.parseFragment(
          '<p>${afterLines.join('<br>')}</p>',
        );
        result.addAll(p.nodes);
      }
    } else if (node is dom.Text && node.text.trim().isEmpty) {
      if (pendingTableRows.isEmpty) {
        result.add(node);
      }
    } else {
      flushTable();
      result.add(node);
    }
  }

  flushTable();
  return result;
}

bool _isTableRow(String trimmed) =>
    trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.length > 2;

List<String> _extractCells(String trimmed) {
  final inner = trimmed.substring(1, trimmed.length - 1);
  return inner.split('|').map((c) => c.trim()).toList();
}

bool _isSeparatorRow(List<String> cells) {
  if (cells.isEmpty) return false;
  return cells.every((c) {
    final t = c.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return t.isNotEmpty && RegExp(r'^[:\- ]+$').hasMatch(t);
  });
}

String _buildTableHtml(List<List<String>> rows) {
  final buf = StringBuffer(
    '<table border="1" cellpadding="6" cellspacing="0" '
    'style="border-collapse: collapse; width: 100%; border: 1px solid #ddd;">',
  );
  if (rows.length > 1) {
    buf.write('<thead><tr>');
    for (final cell in rows.first) {
      buf.write('<th>$cell</th>');
    }
    buf.write('</tr></thead><tbody>');
    for (var r = 1; r < rows.length; r++) {
      buf.write('<tr>');
      for (final cell in rows[r]) {
        buf.write('<td>$cell</td>');
      }
      buf.write('</tr>');
    }
    buf.write('</tbody>');
  } else {
    buf.write('<tbody><tr>');
    for (final cell in rows.first) {
      buf.write('<td>$cell</td>');
    }
    buf.write('</tr></tbody>');
  }
  buf.write('</table>');
  return buf.toString();
}

/// ZenTao sizes images with `<img width>`, which [HtmlToDelta] ignores; it
/// only reads `style`. Copies the attribute into the style so it survives.
String _widthsAsStyle(String html) {
  final doc = html_parser.parseFragment(html);
  var changed = false;
  for (final img in doc.querySelectorAll('img')) {
    final width = img.attributes['width'];
    final style = img.attributes['style'] ?? '';
    if (width == null || style.contains('width')) continue;
    final unit = RegExp(r'^\d+$').hasMatch(width) ? 'px' : '';
    img.attributes['style'] = 'width:$width$unit;$style';
    changed = true;
  }
  return changed ? doc.outerHtml : html;
}

/// The pixel width in an image's `style` (`width:320px`), or null.
String? imageStyleWidth(Object? style) => style is String
    ? RegExp(r'width:\s*(\d+)').firstMatch(style)?.group(1)
    : null;

/// Quill sizes an image through its `style`; the HTML converter writes only
/// a `width` attribute, so the width moves there for ZenTao.
List<Map<String, dynamic>> _withImageWidths(Delta delta) => [
  for (final op in delta.toList())
    if (op.data case final Map<dynamic, dynamic> data
        when data.containsKey('image'))
      {
        'insert': data,
        if (imageStyleWidth(op.attributes?['style']) case final w?)
          'attributes': {'width': w},
      }
    else
      op.toJson().cast<String, dynamic>(),
];

bool _hasEmbeds(Delta delta) => delta.toList().any((op) => op.data is Map);

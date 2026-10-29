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

import '../util/text_sanitize.dart';
import 'editor_table_embed.dart';
import 'html_table_parser.dart';

/// Holds rich text being edited, read from and written back as HTML — the
/// format ZenTao's own editor stores descriptions in.
class HtmlEditingController {
  HtmlEditingController({String html = ''}) : _initialHtml = html {
    quill = QuillController(
      document: _document(html, tableStore),
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
  final TableDataStore tableStore = TableDataStore();

  /// Turns a pasted image into the URL to show it at (by uploading it); a
  /// pasted image is dropped while this is null or gives null.
  Future<String?> Function(Uint8List bytes)? onImagePaste;

  /// The text as HTML; empty when nothing but whitespace was written.
  String get html {
    final delta = quill.document.toDelta();
    if (delta == _initialDelta && !tableStore.hasAnyChanges) {
      return _isBlankHtml(_initialHtml)
          ? ''
          : sanitizeInvisibleChars(_widthsAsAttribute(_initialHtml));
    }
    if (quill.document.toPlainText().trim().isEmpty && !_hasEmbeds(delta)) {
      return '';
    }
    final converter = QuillDeltaToHtmlConverter(
      _withImageWidths(delta),
      ConverterOptions(
        converterOptions: OpConverterOptions(
          inlineStylesFlag: true,
          linkTarget: '',
        ),
      ),
    );
    converter.renderCustomWith = (customOp, contextOp) {
      if (customOp.insert.type == EditorTableEmbedBuilder.tableType) {
        final val = customOp.insert.value;
        final tableId = parseTableId(val);
        final rows =
            (tableId != null ? tableStore.get(tableId) : null) ??
            parseTableRows(val);
        if (rows.isNotEmpty) {
          return '</p>${buildTableHtml(rows, escape: true)}<p>';
        }
      }
      return '';
    };
    final raw = converter.convert();
    final cleaned = raw
        .replaceAll(
          RegExp(r'<p>\s*(<table[^>]*>.*?</table>)\s*</p>', dotAll: true),
          r'$1',
        )
        .replaceAll(RegExp(r'<p>\s*</p>'), '');
    return restoreTables(cleaned);
  }

  void dispose() {
    tableStore.clear();
    quill.dispose();
  }
}

Document _document(String html, TableDataStore tableStore) {
  final source = html.trim();
  if (source.isEmpty) return Document();
  final extracted = _extractTables(_widthsAsStyle(source));
  final delta = HtmlToDelta().convert(extracted.html);
  final replaced = _replaceTablePlaceholders(
    delta,
    extracted.tables,
    tableStore,
  );
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
      rows.add(cells.map(_cleanTableCell).toList());
    }
    if (rows.isNotEmpty) {
      final maxCols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
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

String _cleanTableCell(dom.Element cell) {
  for (final br in cell.querySelectorAll('br')) {
    br.replaceWith(dom.Text('\n'));
  }
  for (final block in cell.querySelectorAll('p, div')) {
    block.append(dom.Text('\n'));
  }
  return sanitizeInvisibleChars(cell.text)
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u00A0', ' ')
      .trim();
}

Delta _replaceTablePlaceholders(
  Delta delta,
  List<List<List<String>>> tables,
  TableDataStore tableStore,
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
            final tableId =
                'table_${DateTime.now().microsecondsSinceEpoch}_$idx';
            tableStore.registerInitial(tableId, tables[idx]);
            newDelta.insert({
              EditorTableEmbedBuilder.tableType: jsonEncode({
                'id': tableId,
                'rows': tables[idx],
              }),
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

/// Copies an image's `style` width into the `width` attribute ZenTao reads,
/// leaving the rest of the (untouched) HTML as it was.
String _widthsAsAttribute(String html) {
  if (!html.contains('<img')) return html;
  final doc = html_parser.parseFragment(html);
  var changed = false;
  for (final img in doc.querySelectorAll('img')) {
    if (img.attributes.containsKey('width')) continue;
    final style = img.attributes['style'] ?? '';
    final width = RegExp(
      r'(?:^|;)\s*width:\s*(\d+)px',
    ).firstMatch(style)?.group(1);
    if (width == null) continue;
    img.attributes['width'] = width;
    changed = true;
  }
  return changed ? doc.outerHtml : html;
}

/// Whether [html] is only whitespace in empty paragraphs (`<p> </p>`).
bool _isBlankHtml(String html) {
  final doc = html_parser.parseFragment(html);
  return doc.text?.trim().isEmpty != false &&
      doc
          .querySelectorAll('*')
          .every((e) => const {'p', 'br', 'div', 'span'}.contains(e.localName));
}

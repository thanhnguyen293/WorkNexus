// Quill marks its clipboard options experimental; pasting images and rich
// text depends on them.
// ignore_for_file: experimental_member_use

import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

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
    final delta = quill.document.toDelta();
    // Untouched text goes back as it came, so markup the editor cannot
    // represent (tables, classes, an iframe) isn't rewritten or dropped by
    // just opening it — unless it holds nothing at all.
    if (delta == _initialDelta) {
      return _isBlankHtml(_initialHtml) ? '' : _widthsAsAttribute(_initialHtml);
    }
    if (quill.document.toPlainText().trim().isEmpty && !_hasEmbeds(delta)) {
      return '';
    }
    final raw = QuillDeltaToHtmlConverter(
      _withImageWidths(delta),
      ConverterOptions(
        converterOptions: OpConverterOptions(
          inlineStylesFlag: true,
          linkTarget: '',
        ),
      ),
    ).convert();
    return _restoreTables(raw);
  }

  void dispose() => quill.dispose();
}

Document _document(String html) {
  final source = html.trim();
  if (source.isEmpty) return Document();
  final preprocessed = _preprocessTables(_widthsAsStyle(source));
  final delta = HtmlToDelta().convert(preprocessed);
  // A document must end with a line break.
  if (delta.isEmpty ||
      !(delta.last.data is String &&
          (delta.last.data! as String).endsWith('\n'))) {
    delta.insert('\n');
  }
  return Document.fromDelta(delta);
}

/// Marks the cell borders `|` of a table flattened by [_preprocessTables].
/// Invisible in the editor, and nothing a user types, so [_restoreTables]
/// rebuilds only those tables — never a paragraph that merely holds pipes.
const _cellMark = '\u2063|';

/// Stands for a line break inside a flattened cell, which would otherwise
/// end the row's line; shown as `↵` and turned back into `<br/>`.
const _cellBreak = '\u2063\u21b5';
final _cellLines = RegExp(r'<br\s*/?>|</p>\s*<p[^>]*>', caseSensitive: false);
final _cellParagraph = RegExp(r'</?p[^>]*>', caseSensitive: false);

/// Converts HTML tables into structured row paragraphs separated by `<br>` so
/// that table rows and cells do not fuse together when converted into Quill.
String _preprocessTables(String html) {
  final doc = html_parser.parseFragment(html);
  final tables = doc.querySelectorAll('table');
  if (tables.isEmpty) return html;

  for (final table in tables) {
    final rows = <String>[];
    for (final tr in table.querySelectorAll('tr')) {
      final cells = tr.querySelectorAll('th, td');
      if (cells.isEmpty) continue;
      final cellTexts = cells.map((c) {
        final inner = c.innerHtml
            .trim()
            .replaceAll(_cellLines, _cellBreak)
            .replaceAll(_cellParagraph, '');
        return inner.isEmpty ? ' ' : inner;
      }).toList();
      rows.add('$_cellMark ${cellTexts.join(' $_cellMark ')} $_cellMark');
    }
    if (rows.isNotEmpty) {
      table.replaceWith(
        html_parser.parseFragment('<p>${rows.join('<br>')}</p>'),
      );
    }
  }
  return doc.outerHtml;
}

/// Rebuilds the `<table>`s [_preprocessTables] flattened into marked rows.
/// The editor may have fused a row with the text around it onto one line, so
/// whatever precedes the first mark or follows the last stays a paragraph.
String _restoreTables(String html) {
  if (!html.contains(_cellMark)) return html;
  final doc = html_parser.parseFragment(html);

  for (final p in doc.querySelectorAll('p, div')) {
    final inner = p.innerHtml;
    if (!inner.contains(_cellMark)) continue;

    final buf = StringBuffer();
    final text = <String>[];
    final rows = <List<String>>[];
    void flushText() {
      if (text.isNotEmpty) buf.write('<p>${text.join('<br/>')}</p>');
      text.clear();
    }

    void flushTable() {
      if (rows.isEmpty) return;
      buf.write(
        '<table border="1" cellpadding="4" cellspacing="0" '
        'style="border-collapse: collapse; width: 100%;"><tbody>',
      );
      for (var r = 0; r < rows.length; r++) {
        final tag = r == 0 ? 'th' : 'td';
        buf.write('<tr>');
        for (final cell in rows[r]) {
          buf.write('<$tag>$cell</$tag>');
        }
        buf.write('</tr>');
      }
      buf.write('</tbody></table>');
      rows.clear();
    }

    void addText(String line) {
      final plain = line.replaceAll(_cellMark[0], '');
      if (plain.trim().isEmpty) return;
      flushTable();
      text.add(plain);
    }

    for (final line in inner.split(RegExp(r'<br\s*/?>'))) {
      final parts = line.split(_cellMark);
      // A row needs a mark on both sides of at least one cell.
      if (parts.length < 3) {
        addText(line);
        continue;
      }
      addText(parts.first);
      flushText();
      rows.add([
        for (final cell in parts.sublist(1, parts.length - 1))
          cell.trim().replaceAll(_cellBreak, '<br/>'),
      ]);
      addText(parts.last);
    }
    flushTable();
    flushText();
    p.replaceWith(html_parser.parseFragment(buf.toString()));
  }

  return doc.outerHtml;
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

/// Whether [html] is only whitespace in empty paragraphs (`<p> </p>`).
bool _isBlankHtml(String html) {
  final doc = html_parser.parseFragment(html);
  return doc.text?.trim().isEmpty != false &&
      doc
          .querySelectorAll('*')
          .every((e) => const {'p', 'br', 'div', 'span'}.contains(e.localName));
}

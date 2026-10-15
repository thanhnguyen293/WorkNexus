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
    if (quill.document.toDelta() == _initialDelta) {
      return _initialHtml;
    }
    if (quill.document.toPlainText().trim().isEmpty &&
        !_hasEmbeds(quill.document.toDelta())) {
      return '';
    }
    final raw = QuillDeltaToHtmlConverter(
      _withImageWidths(quill.document.toDelta()),
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
        final inner = c.innerHtml.replaceAll('|', '&#124;').trim();
        return inner.isEmpty ? ' ' : inner;
      }).toList();
      rows.add('| ${cellTexts.join(' | ')} |');
    }
    if (rows.isNotEmpty) {
      table.replaceWith(
        html_parser.parseFragment('<p>${rows.join('<br>')}</p>'),
      );
    }
  }
  return doc.outerHtml;
}

/// Restores markdown table rows back to clean HTML `<table>` elements.
String _restoreTables(String html) {
  final doc = html_parser.parseFragment(html);
  var modified = false;

  for (final p in doc.querySelectorAll('p, div')) {
    final inner = p.innerHtml;
    if (!inner.contains('|')) continue;

    final parts = inner.split(RegExp(r'<br\s*/?>|\n'));
    final beforeLines = <String>[];
    final tableRows = <List<String>>[];
    final afterLines = <String>[];

    for (final line in parts) {
      final trimmed = line.trim();
      if (trimmed.startsWith('|') &&
          trimmed.endsWith('|') &&
          trimmed.length > 2) {
        final cells = trimmed
            .substring(1, trimmed.length - 1)
            .split('|')
            .map((c) => c.trim())
            .toList();
        tableRows.add(cells);
      } else if (tableRows.isEmpty) {
        if (trimmed.isNotEmpty) beforeLines.add(line);
      } else {
        if (trimmed.isNotEmpty) afterLines.add(line);
      }
    }

    if (tableRows.length >= 2 ||
        (tableRows.length == 1 && tableRows.first.length >= 2)) {
      final buf = StringBuffer();
      if (beforeLines.isNotEmpty) {
        buf.write('<p>${beforeLines.join('<br/>')}</p>');
      }
      buf.write(
        '<table border="1" cellpadding="4" cellspacing="0" '
        'style="border-collapse: collapse; width: 100%;"><tbody>',
      );
      for (var r = 0; r < tableRows.length; r++) {
        final row = tableRows[r];
        buf.write('<tr>');
        final tag = r == 0 ? 'th' : 'td';
        for (final cell in row) {
          buf.write('<$tag>$cell</$tag>');
        }
        buf.write('</tr>');
      }
      buf.write('</tbody></table>');
      if (afterLines.isNotEmpty) {
        buf.write('<p>${afterLines.join('<br/>')}</p>');
      }
      p.replaceWith(html_parser.parseFragment(buf.toString()));
      modified = true;
    }
  }

  return modified ? doc.outerHtml : html;
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

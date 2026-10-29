import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../util/text_sanitize.dart';

/// Restores markdown table rows back to clean HTML `<table>` elements.
String restoreTables(String html) {
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

  void flushTable(List<List<String>> rows, bool hasSeparator) {
    if (rows.isEmpty) return;
    final hasMultipleCols = rows.any((r) => r.length >= 2);
    final isTable =
        (hasSeparator && rows.isNotEmpty && hasMultipleCols) ||
        (rows.length >= 2 && hasMultipleCols);
    if (isTable) {
      final tableHtml = buildTableHtml(rows);
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
      if (!inner.contains('|') || inner.contains('<table')) {
        result.add(node);
        continue;
      }

      final lines = inner.split(RegExp(r'<br\s*/?>|\n'));
      var currentRows = <List<String>>[];
      var currentHasSeparator = false;
      final textLines = <String>[];

      void flushText() {
        if (textLines.isEmpty) return;
        final p = html_parser.parseFragment('<p>${textLines.join('<br>')}</p>');
        result.addAll(p.nodes);
        textLines.clear();
      }

      void flushCurrentTable() {
        if (currentRows.isEmpty) return;
        flushTable(currentRows, currentHasSeparator);
        currentRows = <List<String>>[];
        currentHasSeparator = false;
      }

      for (final line in lines) {
        final trimmed = line.trim();
        if (_isTableRow(trimmed)) {
          final cells = _extractCells(trimmed);
          if (_isSeparatorRow(cells)) {
            currentHasSeparator = true;
          } else {
            flushText();
            currentRows.add(cells);
          }
        } else {
          flushCurrentTable();
          if (trimmed.isNotEmpty) {
            textLines.add(line);
          }
        }
      }

      flushCurrentTable();
      flushText();
    } else {
      result.add(node);
    }
  }

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

String _escapeCellHtml(String cell, {required bool escape}) {
  final clean = sanitizeInvisibleChars(cell).trim();
  if (clean.isEmpty) return '';
  final normalized = clean.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (escape) {
    return normalized
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\n', '<br>');
  }
  return normalized.replaceAll('\n', '<br>');
}

/// Builds HTML `<table>` string from rows matrix, matching ZenTao native KindEditor
/// table structure with natural auto-width and compact 5px cell padding.
String buildTableHtml(List<List<String>> rows, {bool escape = false}) {
  if (rows.isEmpty) return '';

  // Filter trailing completely empty rows so accidental empty rows don't show up in ZenTao.
  final cleanRows = List<List<String>>.from(rows);
  while (cleanRows.length > 1 &&
      cleanRows.last.every((cell) => cell.trim().isEmpty)) {
    cleanRows.removeLast();
  }

  final buf = StringBuffer(
    '<table style="border-collapse:collapse;border:1px solid #000000;">',
  );
  if (cleanRows.length > 1) {
    buf.write('<thead><tr>');
    for (final cell in cleanRows.first) {
      buf.write(
        '<th style="border:1px solid #000000;padding:5px;font-weight:600;text-align:left;">'
        '${_escapeCellHtml(cell, escape: escape)}'
        '</th>',
      );
    }
    buf.write('</tr></thead><tbody>');
    for (var r = 1; r < cleanRows.length; r++) {
      buf.write('<tr>');
      for (final cell in cleanRows[r]) {
        final content = _escapeCellHtml(cell, escape: escape);
        buf.write(
          '<td style="border:1px solid #000000;padding:5px;text-align:left;">$content</td>',
        );
      }
      buf.write('</tr>');
    }
    buf.write('</tbody>');
  } else {
    buf.write('<tbody><tr>');
    for (final cell in cleanRows.first) {
      final content = _escapeCellHtml(cell, escape: escape);
      buf.write(
        '<td style="border:1px solid #000000;padding:5px;text-align:left;">$content</td>',
      );
    }
    buf.write('</tr></tbody>');
  }
  buf.write('</table>');
  return buf.toString();
}

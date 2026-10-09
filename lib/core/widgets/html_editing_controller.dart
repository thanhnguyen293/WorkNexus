import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// Holds rich text being edited, read from and written back as HTML — the
/// format ZenTao's own editor stores descriptions in.
class HtmlEditingController {
  HtmlEditingController({String html = ''}) {
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
  }

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
    return QuillDeltaToHtmlConverter(
      _withImageWidths(quill.document.toDelta()),
      ConverterOptions(
        converterOptions: OpConverterOptions(
          inlineStylesFlag: true,
          linkTarget: '',
        ),
      ),
    ).convert();
  }

  void dispose() => quill.dispose();
}

Document _document(String html) {
  final source = html.trim();
  if (source.isEmpty) return Document();
  final delta = HtmlToDelta().convert(_widthsAsStyle(source));
  // A document must end with a line break.
  if (delta.isEmpty ||
      !(delta.last.data is String &&
          (delta.last.data! as String).endsWith('\n'))) {
    delta.insert('\n');
  }
  return Document.fromDelta(delta);
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

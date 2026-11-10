import 'package:html2md/html2md.dart' as html2md;

import '../../domain/entities/zentao_doc.dart';

/// [doc] as Markdown for the clipboard: its title as a heading, then the body
/// with fenced code and GFM tables, so it pastes into a chat, an issue or an
/// editor with its structure kept. Falls back to the body's text when the
/// conversion fails.
String zenTaoDocMarkdown(ZenTaoDoc doc) {
  final body = doc.html.trim();
  String converted;
  try {
    converted = body.isEmpty
        ? ''
        : html2md.convert(
            body,
            styleOptions: const {
              'headingStyle': 'atx',
              'codeBlockStyle': 'fenced',
              'bulletListMarker': '-',
            },
          );
  } on Object {
    converted = body.replaceAll(RegExp('<[^>]*>'), '');
  }
  converted = converted.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return converted.isEmpty ? '# ${doc.title}' : '# ${doc.title}\n\n$converted';
}

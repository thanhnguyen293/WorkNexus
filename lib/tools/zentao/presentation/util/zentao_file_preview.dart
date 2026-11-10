import '../../../../core/domain/entities/provider_entity.dart';

/// How an attached file can be shown in place, if at all.
enum ZenTaoFilePreview { markdown, text, image, none }

const _markdown = {'md', 'markdown'};
const _image = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
const _text = {
  'txt',
  'log',
  'json',
  'yaml',
  'yml',
  'xml',
  'csv',
  'tsv',
  'sql',
  'ini',
  'toml',
  'env',
  'sh',
  'proto',
  'go',
  'dart',
  'js',
  'ts',
  'java',
  'kt',
  'swift',
  'py',
  'rb',
  'php',
  'html',
  'css',
};

/// What [file] previews as. The name's own extension wins over the one ZenTao
/// reports: it files a `.md` upload as `txt`, which would show the Markdown
/// as raw text.
ZenTaoFilePreview zenTaoFilePreviewOf(TicketAttachment file) {
  for (final ext in [_extOf(file.title), file.extension?.toLowerCase()]) {
    if (ext == null) continue;
    if (_markdown.contains(ext)) return ZenTaoFilePreview.markdown;
    if (_image.contains(ext)) return ZenTaoFilePreview.image;
    if (_text.contains(ext)) return ZenTaoFilePreview.text;
  }
  return ZenTaoFilePreview.none;
}

String? _extOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 || dot == name.length - 1
      ? null
      : name.substring(dot + 1).toLowerCase();
}

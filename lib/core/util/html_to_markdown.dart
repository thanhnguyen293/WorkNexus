import 'package:html2md/html2md.dart' as html2md;

/// Converts rich-text HTML (ZenTao's bug steps / task desc / story spec /
/// comments) into Markdown — for where Markdown is wanted rather than shown,
/// such as the text sent to translate. Falls back to the
/// text without its tags if conversion throws. Plain/empty input passes through
/// unchanged.
///
/// Note: we deliberately do NOT use html2md's `imageBaseUrl` — it prepends the
/// base even to already-absolute `src`s (producing `.../base/https://.../x.png`).
/// ZenTao emits absolute image URLs, and relative ones are resolved later by the
/// authenticated image loader.
String htmlToMarkdown(String html) {
  final s = html.trim();
  if (s.isEmpty) return '';
  if (!s.contains('<')) return s; // already plain text / markdown
  try {
    return html2md.convert(s).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  } catch (_) {
    return s.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}

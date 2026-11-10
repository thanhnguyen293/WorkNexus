import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;

/// Cleans the HTML ZenTao 21's block editor exports for a document, which
/// carries editor artefacts that read as noise outside its web page:
/// - `<pre>` boxes pinned to a white background (`style="background-color:
///   #FFFFFF"`), glaring on a dark surface;
/// - tables opened by an empty header row (`<th></th><th></th>`) when the
///   author used a plain key/value grid;
/// - empty paragraphs left between blocks, each a full blank line.
String tidyZenTaoDocHtml(String html) {
  if (html.trim().isEmpty) return html;
  final fragment = parseFragment(html);
  for (final pre in fragment.querySelectorAll('pre')) {
    pre.attributes.remove('style');
  }
  for (final selector in const ['thead', 'tr', 'p']) {
    for (final element in fragment.querySelectorAll(selector)) {
      if (_isBlank(element)) element.remove();
    }
  }
  return fragment.outerHtml;
}

bool _isBlank(Element e) =>
    e.text.trim().isEmpty && e.querySelector('img') == null;

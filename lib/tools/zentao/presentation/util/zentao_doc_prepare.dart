import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;

/// A heading of a document, for its outline: [index] is the one its marker
/// (`<zt-anchor data-heading>`) carries, which the reader scrolls to.
typedef ZenTaoDocHeading = ({int level, String text, int index});

/// A document body ready for the reader: [html] with its headings anchored
/// and the find matches marked, the [headings] in order, and [matchCount].
typedef ZenTaoDocPrepared = ({
  String html,
  List<ZenTaoDocHeading> headings,
  int matchCount,
});

/// The tag a find match is wrapped in; its `data-find` is its index (0..).
const zenTaoFindTag = 'mark';
const zenTaoFindAttr = 'data-find';

/// The empty marker put at the start of each outlined heading; its
/// `data-heading` is the heading's index. The reader draws it as a zero-size
/// keyed widget, to scroll to the heading and see where it is.
const zenTaoAnchorTag = 'zt-anchor';
const zenTaoAnchorAttr = 'data-heading';

/// More matches than this are left unmarked: a one-letter search in a long
/// document would otherwise turn every other word into a widget.
const zenTaoFindLimit = 500;

/// Prepares [html] for reading: headings `h1`–`h4` get a marker
/// (`<zt-anchor data-heading="N">`) and become the outline; every
/// case-insensitive match of [query] in the text — code included — is
/// wrapped in `<mark data-find="N">`, in reading order.
ZenTaoDocPrepared prepareZenTaoDocHtml(String html, {String query = ''}) {
  if (html.trim().isEmpty) {
    return (html: html, headings: const [], matchCount: 0);
  }
  final fragment = parseFragment(html);

  final headings = <ZenTaoDocHeading>[];
  for (final h in fragment.querySelectorAll('h1, h2, h3, h4')) {
    final text = h.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) continue;
    final index = headings.length;
    final marker = Element.tag(zenTaoAnchorTag)
      ..attributes[zenTaoAnchorAttr] = '$index';
    if (h.firstChild case final first?) {
      h.insertBefore(marker, first);
    } else {
      h.append(marker);
    }
    headings.add((
      level: int.parse(h.localName!.substring(1)),
      text: text,
      index: index,
    ));
  }

  var count = 0;
  final q = query.trim();
  if (q.isNotEmpty) {
    final pattern = RegExp(RegExp.escape(q), caseSensitive: false);
    for (final node in _textNodes(fragment)) {
      if (count >= zenTaoFindLimit) break;
      final text = node.text;
      final matches = pattern.allMatches(text).toList();
      if (matches.isEmpty) continue;
      final parent = node.parentNode;
      if (parent == null) continue;
      var at = 0;
      for (final m in matches) {
        if (count >= zenTaoFindLimit) break;
        if (m.start > at) {
          parent.insertBefore(Text(text.substring(at, m.start)), node);
        }
        final mark = Element.tag(zenTaoFindTag)
          ..attributes[zenTaoFindAttr] = '$count'
          ..append(Text(m.group(0)));
        parent.insertBefore(mark, node);
        count++;
        at = m.end;
      }
      if (at < text.length) {
        parent.insertBefore(Text(text.substring(at)), node);
      }
      node.remove();
    }
  }

  return (html: fragment.outerHtml, headings: headings, matchCount: count);
}

/// Every text node under [root], in document order (collected first, as
/// marking replaces them).
List<Text> _textNodes(Node root) {
  final out = <Text>[];
  void walk(Node n) {
    for (final child in n.nodes) {
      if (child is Text) {
        out.add(child);
      } else {
        walk(child);
      }
    }
  }

  walk(root);
  return out;
}

/// The marks under [e] (a `<pre>` or inline `<code>`), as their indices and
/// ranges in [e]'s text.
List<({int index, int start, int end})> zenTaoFindRanges(Element e) {
  final out = <({int index, int start, int end})>[];
  var offset = 0;
  void walk(Node n) {
    for (final child in n.nodes) {
      if (child is Text) {
        offset += child.text.length;
      } else if (child is Element) {
        final index = child.localName == zenTaoFindTag
            ? int.tryParse(child.attributes[zenTaoFindAttr] ?? '')
            : null;
        final start = offset;
        walk(child);
        if (index != null) {
          out.add((index: index, start: start, end: offset));
        }
      }
    }
  }

  walk(e);
  return out;
}

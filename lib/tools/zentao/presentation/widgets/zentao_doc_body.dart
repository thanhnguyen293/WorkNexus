import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_image.dart';
import '../util/zentao_doc_prepare.dart';
import 'zentao_doc_code_block.dart';
import 'zentao_doc_inline.dart';
import 'zentao_doc_reader_controller.dart';

/// A ZenTao document's HTML body, styled as a reference page rather than a
/// comment (the data layer has already tidied the editor's artefacts). Code
/// goes through
/// [ZenTaoDocCodeBlock], tables get a ruled grid with a shaded header row,
/// and headings a rhythm with more air above than below.
///
/// A sliver (it sits in the reader's [CustomScrollView]) holding the whole
/// body built at once. Built lazily, the page's length was guessed from the
/// blocks on screen — short paragraphs beside long code blocks and tables —
/// and the scrollbar jumped as it scrolled; built whole, the length is exact.
/// The library's own lazy sliver can't be given a steadier guess (it only
/// treats its own `RenderMode.sliverList` instance as a sliver).
class ZenTaoDocBody extends StatelessWidget {
  const ZenTaoDocBody(
    this.html, {
    super.key,
    required this.reader,
    required this.imageLoader,
    this.imageFallbackUrl,
  });

  /// Prepared by `prepareZenTaoDocHtml`: headings carry markers, find
  /// matches are wrapped in `<mark>`.
  final String html;
  final ZenTaoDocReader reader;
  final ImageBytesLoader imageLoader;
  final ImageUrlResolver? imageFallbackUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final prose = t.prose.copyWith(color: c.textPrimary);
    final rule = '${context.borders.hairline}px solid ${_css(c.border)}';
    final cell = '${s.md}px ${s.xl}px';

    Map<String, String> heading(TextStyle style, double above) => {
      'font-size': '${style.fontSize}px',
      'font-weight': '600',
      'line-height': '1.3',
      'margin': '${above}px 0 ${s.md}px',
    };

    return SliverToBoxAdapter(
      child: HtmlWidget(
        html,
        textStyle: prose,
        onTapUrl: (url) {
          openLinkExternally(url);
          return true;
        },
        customStylesBuilder: (e) => switch (e.localName) {
          'h1' => heading(t.display, s.xl6),
          'h2' => heading(t.titleLg, s.xl6),
          'h3' => heading(t.title, s.xl5),
          'h4' => heading(t.titleSm, s.xl5),
          'h5' || 'h6' => heading(t.subtitle, s.xl4),
          'p' => {'margin': '0 0 ${s.lg}px'},
          'ul' || 'ol' => {'margin': '0 0 ${s.lg}px'},
          'li' => {'margin': '0 0 ${s.xs}px'},
          'a' => {'color': _css(c.accent)},
          'table' => {
            'border-collapse': 'collapse',
            'border': rule,
            'margin': '${s.md}px 0 ${s.xl4}px',
          },
          'th' => {
            'border': rule,
            'padding': cell,
            'background-color': _css(c.surfaceSubtle),
            'font-weight': '600',
            'text-align': 'left',
            'vertical-align': 'top',
          },
          'td' => {'border': rule, 'padding': cell, 'vertical-align': 'top'},
          'hr' => {'margin': '${s.xl5}px 0', 'border-top': rule},
          _ => null,
        },
        customWidgetBuilder: (e) => switch (e.localName) {
          zenTaoAnchorTag => InlineCustomWidget(
            child: SizedBox.shrink(
              key: reader.headingKey(_index(e, zenTaoAnchorAttr)),
            ),
          ),
          zenTaoFindTag => InlineCustomWidget(
            child: ZenTaoDocFindMark(
              key: reader.matchKey(_index(e, zenTaoFindAttr)),
              text: e.text,
              index: _index(e, zenTaoFindAttr),
              style: _markStyle(context, e),
              reader: reader,
            ),
          ),
          'pre' => _hosting(
            e,
            Padding(
              padding: EdgeInsets.only(top: s.xs, bottom: s.xl),
              child: ZenTaoDocCodeBlock(
                _codeOf(e),
                fontSize: (t.prose.fontSize ?? 14) - 1.5,
                reader: reader,
                matches: zenTaoFindRanges(e),
              ),
            ),
          ),
          // Inline code (a `<pre>`'s own `<code>` never gets here): a chip, as
          // ZenTao's web draws it.
          'code' => InlineCustomWidget(
            alignment: PlaceholderAlignment.middle,
            child: _hosting(
              e,
              ZenTaoDocInlineCode(
                e.text,
                fontSize: (t.prose.fontSize ?? 14) * 0.88,
                reader: reader,
                matches: [for (final m in zenTaoFindRanges(e)) m.index],
              ),
            ),
          ),
          'img' => _image(e),
          _ => null,
        },
      ),
    );
  }

  /// [child] drawn for element [e], keyed for the first find match inside
  /// it; the others are filed under that key, so stepping to any of them
  /// scrolls to [child].
  Widget _hosting(dom.Element e, Widget child) {
    final matches = zenTaoFindRanges(e);
    if (matches.isEmpty) return child;
    final host = matches.first.index;
    for (final m in matches) {
      reader.hostMatch(m.index, host);
    }
    return KeyedSubtree(key: reader.matchKey(host), child: child);
  }

  static int _index(dom.Element e, String attr) =>
      int.tryParse(e.attributes[attr] ?? '') ?? 0;

  /// The text style a find match inherits from where it sits — a heading's
  /// size, bold, italic, a link's colour — since it is drawn as a widget of
  /// its own, outside the page's styled text.
  TextStyle _markStyle(BuildContext context, dom.Element e) {
    final t = context.typography;
    final c = context.colors;
    var style = t.prose.copyWith(color: c.textPrimary);
    var bold = false;
    var italic = false;
    for (var p = e.parent; p != null; p = p.parent) {
      switch (p.localName) {
        case 'h1':
          style = style.copyWith(fontSize: t.display.fontSize, height: 1.3);
          bold = true;
        case 'h2':
          style = style.copyWith(fontSize: t.titleLg.fontSize, height: 1.3);
          bold = true;
        case 'h3':
          style = style.copyWith(fontSize: t.title.fontSize, height: 1.3);
          bold = true;
        case 'h4':
          style = style.copyWith(fontSize: t.titleSm.fontSize, height: 1.3);
          bold = true;
        case 'h5' || 'h6':
          style = style.copyWith(fontSize: t.subtitle.fontSize, height: 1.3);
          bold = true;
        case 'strong' || 'b' || 'th':
          bold = true;
        case 'em' || 'i':
          italic = true;
        case 'a':
          style = style.copyWith(color: c.accent);
      }
    }
    return style.copyWith(
      fontWeight: bold ? FontWeight.w600 : null,
      fontStyle: italic ? FontStyle.italic : null,
    );
  }

  Widget? _image(dom.Element e) {
    final src = e.attributes['src']?.trim() ?? '';
    if (src.isEmpty) return null;
    return InlineImage(
      key: ValueKey(src),
      url: src,
      loader: imageLoader,
      fallbackUrl: imageFallbackUrl,
    );
  }

  /// The code a `<pre>` holds, without the trailing newline the editor adds.
  static String _codeOf(dom.Element pre) =>
      pre.text.replaceFirst(RegExp(r'\n+$'), '');

  static String _css(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_image.dart';
import 'zentao_doc_code_block.dart';

/// A ZenTao document's HTML body, styled as a reference page rather than a
/// comment (the data layer has already tidied the editor's artefacts). Code
/// goes through
/// [ZenTaoDocCodeBlock], tables get a ruled grid with a shaded header row,
/// and headings a rhythm with more air above than below.
///
/// Renders as a sliver list (lazily), so it must sit in a [CustomScrollView].
class ZenTaoDocBody extends StatelessWidget {
  const ZenTaoDocBody(
    this.html, {
    super.key,
    required this.imageLoader,
    this.imageFallbackUrl,
  });

  final String html;
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

    return HtmlWidget(
      html,
      renderMode: RenderMode.sliverList,
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
        'pre' => Padding(
          padding: EdgeInsets.only(top: s.xs, bottom: s.xl),
          child: ZenTaoDocCodeBlock(
            _codeOf(e),
            fontSize: (t.prose.fontSize ?? 14) - 1.5,
          ),
        ),
        // Inline code (a `<pre>`'s own `<code>` never gets here): a chip, as
        // ZenTao's web draws it.
        'code' => InlineCustomWidget(
          alignment: PlaceholderAlignment.middle,
          child: _InlineCode(e.text, fontSize: (t.prose.fontSize ?? 14) * 0.88),
        ),
        'img' => _image(e),
        _ => null,
      },
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

class _InlineCode extends StatelessWidget {
  const _InlineCode(this.code, {required this.fontSize});

  final String code;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: s.xxs),
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.xs),
        border: Border.all(color: c.border, width: context.borders.hairline),
      ),
      child: Text(
        code,
        style: context.typography.mono.copyWith(
          fontSize: fontSize,
          color: c.textPrimary,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../platform/open_external.dart';
import '../theme/app_colors.dart';
import 'inline_image.dart';

/// Renders a provider's HTML as it is — ZenTao's descriptions and comments
/// come from its rich-text editor — in the app's text style.
///
/// [imageLoader], when provided, fetches `<img>`s through an authenticated
/// transport (ZenTao's assets are session-protected, behind self-signed TLS),
/// with the same loading / broken / "open in browser" states as Markdown.
class HtmlText extends StatelessWidget {
  const HtmlText(
    this.html, {
    super.key,
    this.fontSize = 13,
    this.height = 1.6,
    this.imageLoader,
    this.imageFallbackUrl,
    this.onOpenImage,
    this.onLinkTap,
  });

  final String html;
  final double fontSize;
  final double height;
  final ImageBytesLoader? imageLoader;
  final ImageUrlResolver? imageFallbackUrl;
  final ImageExternalOpener? onOpenImage;

  /// Handles a tapped link; null opens web links in the browser.
  final void Function(String url)? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = TextStyle(
      fontSize: fontSize,
      height: height,
      color: c.textPrimary,
    );
    if (html.trim().isEmpty) {
      return Text('—', style: style.copyWith(color: c.textTertiary));
    }
    final loader = imageLoader;
    final onLink = onLinkTap ?? openLinkExternally;
    final link = _cssColor(c.accent);
    final border = _cssColor(c.border);
    final headerBg = _cssColor(c.surfaceSubtle);
    final codeBg = _cssColor(c.surfaceSubtle);
    return HtmlWidget(
      html,
      textStyle: style,
      customStylesBuilder: (element) {
        switch (element.localName) {
          case 'a':
            return {'color': link};
          case 'table':
            return {
              'border-collapse': 'collapse',
              'width': '100%',
              'margin': '8px 0',
              'border': '1px solid $border',
            };
          case 'th':
            return {
              'border': '1px solid $border',
              'padding': '6px 10px',
              'background-color': headerBg,
              'font-weight': '600',
              'text-align': 'left',
            };
          case 'td':
            return {
              'border': '1px solid $border',
              'padding': '6px 10px',
              'vertical-align': 'top',
            };
          case 'code':
            return {
              'background-color': codeBg,
              'padding': '2px 4px',
              'border-radius': '4px',
              'font-family': 'monospace',
            };
          case 'pre':
            return {
              'background-color': codeBg,
              'padding': '8px 12px',
              'border-radius': '6px',
              'border': '1px solid $border',
            };
          default:
            return null;
        }
      },
      customWidgetBuilder: (element) {
        final src = element.attributes['src']?.trim() ?? '';
        if (loader == null || element.localName != 'img' || src.isEmpty) {
          return null;
        }
        return InlineImage(
          // Keyed by URL so a body refresh with a new URL fetches it afresh.
          key: ValueKey(src),
          url: src,
          loader: loader,
          fallbackUrl: imageFallbackUrl,
          onOpenImage: onOpenImage,
        );
      },
      onTapUrl: (url) {
        onLink(url);
        return true;
      },
    );
  }
}

String _cssColor(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

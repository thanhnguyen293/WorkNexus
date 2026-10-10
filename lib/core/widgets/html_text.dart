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
    return HtmlWidget(
      html,
      textStyle: style,
      customStylesBuilder: (element) =>
          element.localName == 'a' ? {'color': link} : null,
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

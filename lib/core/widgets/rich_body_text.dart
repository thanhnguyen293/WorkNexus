import 'package:flutter/material.dart';

import 'html_text.dart';
import 'markdown_text.dart';

/// A description or comment in the format its provider wrote it: HTML (ZenTao)
/// through [HtmlText], Markdown (GitHub, GitLab) through [MarkdownText].
class RichBodyText extends StatelessWidget {
  const RichBodyText(
    this.text, {
    super.key,
    required this.html,
    this.fontSize = 13,
    this.height = 1.6,
    this.imageLoader,
    this.imageFallbackUrl,
    this.onOpenImage,
  });

  final String text;

  /// Whether [text] is HTML (see `isHtmlBody`).
  final bool html;
  final double fontSize;
  final double height;
  final ImageBytesLoader? imageLoader;
  final ImageUrlResolver? imageFallbackUrl;
  final ImageExternalOpener? onOpenImage;

  @override
  Widget build(BuildContext context) => html
      ? HtmlText(
          text,
          fontSize: fontSize,
          height: height,
          imageLoader: imageLoader,
          imageFallbackUrl: imageFallbackUrl,
          onOpenImage: onOpenImage,
        )
      : MarkdownText(
          text,
          fontSize: fontSize,
          height: height,
          imageLoader: imageLoader,
          imageFallbackUrl: imageFallbackUrl,
          onOpenImage: onOpenImage,
        );
}

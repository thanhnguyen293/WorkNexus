import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/fonts.dart';
import '../util/markdown_normalize.dart';
import 'hover_surface.dart';
import 'inline_image.dart';

export 'inline_image.dart'
    show ImageBytesLoader, ImageExternalOpener, ImageUrlResolver;

/// Renders GitHub-flavored Markdown using the app's text tokens.
///
/// Ticket bodies, translations and comments all flow through here. Content is
/// Markdown by the time it reaches the UI: GitHub/GitLab already speak it, and
/// ZenTao's HTML is converted to Markdown at normalize time.
///
/// [imageLoader], when provided, fetches inline images through an authenticated
/// transport (needed for ZenTao's session-protected, self-signed-TLS assets);
/// without it, images fall back to the default network loader.
class MarkdownText extends StatelessWidget {
  const MarkdownText(
    this.data, {
    super.key,
    this.fontSize = 13,
    this.color,
    this.height = 1.6,
    this.imageLoader,
    this.imageFallbackUrl,
    this.onOpenImage,
    this.linkColor,
    this.onLinkTap,
    this.isPlainLink,
  });

  final String data;
  final double fontSize;
  final Color? color;
  final double height;
  final ImageBytesLoader? imageLoader;

  /// Resolves an inline image URL to an absolute link. When it yields non-null
  /// for an image whose bytes failed to load, a "copy link / open in browser"
  /// bar is shown instead of the broken-image icon — so a session-protected
  /// asset (e.g. a GitLab < 17.4 upload) stays reachable.
  final ImageUrlResolver? imageFallbackUrl;

  /// Opens the resolved fallback link externally (see [imageFallbackUrl]).
  final ImageExternalOpener? onOpenImage;

  /// Link colour; defaults to the accent (override on accent backgrounds).
  final Color? linkColor;

  /// Handles a tapped link; null leaves it to the markdown renderer.
  final void Function(String url)? onLinkTap;

  /// Links drawn in the link colour only, without an underline (e.g. chat
  /// mentions).
  final bool Function(String url)? isPlainLink;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = TextStyle(
      fontSize: fontSize,
      height: height,
      color: color ?? c.textPrimary,
    );
    final text = normalizeMarkdown(data.trim());
    if (text.isEmpty) {
      return Text('—', style: base.copyWith(color: c.textTertiary));
    }
    final onLink = onLinkTap;
    return GptMarkdown(
      text,
      style: base,
      onLinkTap: onLink == null ? null : (url, _) => onLink(url),
      // Keyed by URL so that when a body refresh (e.g. the detail sync landing
      // in drift) changes an image's URL, the old element's state — and the
      // failed/stale future memoized inside it — is discarded and the new URL
      // is actually fetched.
      imageBuilder: imageLoader == null
          ? null
          : (context, url, width, height) => InlineImage(
              key: ValueKey(url),
              url: url,
              loader: imageLoader!,
              fallbackUrl: imageFallbackUrl,
              onOpenImage: onOpenImage,
              width: width,
            ),
      // gpt_markdown wraps a custom link in a bare GestureDetector, so the
      // hand cursor (and, for plain links, the hover underline) is ours to add.
      linkBuilder: (context, label, url, style) {
        final plain = isPlainLink?.call(url) ?? false;
        return HoverRegion(
          enabled: onLink != null,
          cursor: SystemMouseCursors.click,
          builder: (context, hovered, _) => Text(
            label.toPlainText(),
            style: style.copyWith(
              color: linkColor ?? c.accent,
              fontWeight: plain ? FontWeight.w600 : null,
              decoration: plain && !hovered
                  ? TextDecoration.none
                  : TextDecoration.underline,
              decorationColor: linkColor ?? c.accent,
            ),
          ),
        );
      },
      codeBuilder: (context, name, code, closed) => Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: context.spacing.sm),
        padding: EdgeInsets.all(context.spacing.lg),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.sm),
          border: Border.all(color: c.border),
        ),
        child: SelectableText(
          code,
          style: TextStyle(
            fontSize: fontSize - 1,
            fontFamily: kMonoFont,
            color: c.textPrimary,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

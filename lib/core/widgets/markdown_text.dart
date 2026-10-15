import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../platform/open_external.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../util/markdown_normalize.dart';
import 'code_block.dart';
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
    this.underlineLinksOnHover = false,
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

  /// Handles a tapped link; null opens web links in the browser.
  final void Function(String url)? onLinkTap;

  /// Links drawn in the link colour only, without an underline (e.g. chat
  /// mentions).
  final bool Function(String url)? isPlainLink;

  /// Draws every link without an underline until hovered, as GitLab / GitHub
  /// do in a description.
  final bool underlineLinksOnHover;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = TextStyle(
      fontSize: fontSize,
      height: height,
      color: color ?? c.textPrimary,
    );
    final text = linkifyBareUrls(normalizeMarkdown(data.trim()));
    if (text.isEmpty) {
      return Text('—', style: base.copyWith(color: c.textTertiary));
    }
    final onLink = onLinkTap ?? openLinkExternally;
    // Headings scale from the body size (the package default is the Material
    // headline ramp, which dwarfs 13–14px body text). Ratios follow GitLab's
    // rendered markdown.
    TextStyle heading(double scale) => base.copyWith(
      fontSize: fontSize * scale,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    return GptMarkdownTheme(
      gptThemeData: GptMarkdownThemeData(
        brightness: Theme.of(context).brightness,
        h1: heading(1.6),
        h2: heading(1.4),
        h3: heading(1.2),
        h4: heading(1.1),
        h5: heading(1),
        h6: heading(1),
        hrLineColor: c.border,
      ),
      child: GptMarkdown(
        text,
        style: base,
        onLinkTap: (url, _) => onLink(url),
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
        inlineLinkBuilder: (details) {
          final plain = isPlainLink?.call(details.url) ?? false;
          final linkCol = linkColor ?? c.accent;
          if (plain) {
            return details.asWidgetSpan(
              HoverRegion(
                cursor: SystemMouseCursors.click,
                builder: (context, hovered, _) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.5,
                    vertical: 0.5,
                  ),
                  decoration: BoxDecoration(
                    color: hovered
                        ? linkCol.withValues(alpha: 0.22)
                        : linkCol.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    details.label,
                    style: details.style.copyWith(
                      color: linkCol,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            );
          }
          return details.asWidgetSpan(
            HoverRegion(
              cursor: SystemMouseCursors.click,
              builder: (context, hovered, _) => Text(
                details.label,
                style: details.style.copyWith(
                  color: linkCol,
                  decoration: underlineLinksOnHover && !hovered
                      ? TextDecoration.none
                      : TextDecoration.underline,
                  decorationColor: linkCol,
                ),
              ),
            ),
          );
        },
        codeBuilder: (context, name, code, closed) => Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
          child: CodeBlock(code, fontSize: fontSize - 1),
        ),
        inlineCodeBuilder: (context, code, style, codeStyle) =>
            baselineWidgetSpan(_InlineCode(code, style)),
      ),
    );
  }
}

/// Inline `code`: monospace on a faint tint of the text colour, so it reads on
/// any surface (a light panel, a dark one, an accent chat bubble).
class _InlineCode extends StatelessWidget {
  const _InlineCode(this.code, this.style);

  final String code;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = style.color ?? c.textPrimary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
      decoration: BoxDecoration(
        color: c.mixT(ink, 0.08),
        borderRadius: BorderRadius.circular(context.radii.xs),
      ),
      child: Text(
        code,
        style: style.copyWith(
          fontFamily: context.typography.mono.fontFamily,
          // Mono glyphs run wide; a step down keeps them level with the prose.
          fontSize: (style.fontSize ?? 13) * 0.9,
          color: ink,
        ),
      ),
    );
  }
}

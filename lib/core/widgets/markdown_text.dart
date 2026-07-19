import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/fonts.dart';

/// Loads the bytes for an inline image URL (e.g. via an authenticated client).
typedef ImageBytesLoader = Future<Uint8List?> Function(String url);

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
  });

  final String data;
  final double fontSize;
  final Color? color;
  final double height;
  final ImageBytesLoader? imageLoader;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = TextStyle(
      fontSize: fontSize,
      height: height,
      color: color ?? c.textPrimary,
    );
    final text = data.trim();
    if (text.isEmpty) {
      return Text('—', style: base.copyWith(color: c.textTertiary));
    }
    return GptMarkdown(
      text,
      style: base,
      // Keyed by URL so that when a body refresh (e.g. the detail sync landing
      // in drift) changes an image's URL, the old element's state — and the
      // failed/stale future memoized inside it — is discarded and the new URL
      // is actually fetched.
      imageBuilder: imageLoader == null
          ? null
          : (context, url, width, height) => _MarkdownImage(
              key: ValueKey(url),
              url: url,
              loader: imageLoader!,
              width: width,
            ),
      linkBuilder: (context, label, url, style) => Text(
        label.toPlainText(),
        style: style.copyWith(
          color: c.accent,
          decoration: TextDecoration.underline,
        ),
      ),
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

/// An inline image fetched through [ImageBytesLoader] (memoized so it isn't
/// refetched on every markdown rebuild), with loading / broken states.
class _MarkdownImage extends StatefulWidget {
  const _MarkdownImage({
    super.key,
    required this.url,
    required this.loader,
    this.width,
  });

  final String url;
  final ImageBytesLoader loader;
  final double? width;

  @override
  State<_MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<_MarkdownImage> {
  late final Future<Uint8List?> _future = widget.loader(widget.url);

  Widget _frame(BuildContext context, Widget child) => Container(
    height: 140,
    margin: EdgeInsets.symmetric(vertical: context.spacing.sm),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.colors.surfaceSubtle,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: Border.all(color: context.colors.border),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _frame(
            context,
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.textTertiary,
              ),
            ),
          );
        }
        final bytes = snap.data;
        if (bytes == null) {
          return _frame(
            context,
            Icon(Icons.broken_image_outlined, color: c.textTertiary, size: 22),
          );
        }
        return Container(
          padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
          constraints: const BoxConstraints(maxHeight: 400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.radii.md),
            child: Image.memory(
              bytes,
              width: widget.width,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _frame(
                context,
                Icon(Icons.broken_image_outlined, color: c.textTertiary),
              ),
            ),
          ),
        );
      },
    );
  }
}

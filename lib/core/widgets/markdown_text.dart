import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/fonts.dart';

/// Loads the bytes for an inline image URL (e.g. via an authenticated client).
typedef ImageBytesLoader = Future<Uint8List?> Function(String url);

/// Resolves an inline image [url] to an absolute link that can be copied or
/// opened in a browser, or null if it can't be resolved.
typedef ImageUrlResolver = String? Function(String url);

/// Opens an already-resolved image [url] externally (in a browser).
typedef ImageExternalOpener = Future<void> Function(String url);

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
              fallbackUrl: imageFallbackUrl,
              onOpenImage: onOpenImage,
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
    this.fallbackUrl,
    this.onOpenImage,
    this.width,
  });

  final String url;
  final ImageBytesLoader loader;
  final ImageUrlResolver? fallbackUrl;
  final ImageExternalOpener? onOpenImage;
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
          // The bytes couldn't be fetched in-app (e.g. a session-protected
          // GitLab upload on a pre-17.4 server, unreadable with a PAT). When a
          // fallback URL resolves, offer to copy it or open it externally —
          // where the user's browser session can read it — instead of a broken
          // placeholder.
          final resolved = widget.fallbackUrl?.call(widget.url);
          if (resolved == null) {
            return _frame(
              context,
              Icon(
                Icons.broken_image_outlined,
                color: c.textTertiary,
                size: 22,
              ),
            );
          }
          return _frame(
            context,
            _ImageFallbackActions(url: resolved, onOpen: widget.onOpenImage),
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

/// The action bar shown in place of an inline image whose bytes couldn't be
/// fetched: copy the resolved link, or open it in a browser (see
/// [MarkdownText.imageFallbackUrl]). Copy shows a transient "copied" state.
class _ImageFallbackActions extends StatefulWidget {
  const _ImageFallbackActions({required this.url, this.onOpen});

  final String url;
  final ImageExternalOpener? onOpen;

  @override
  State<_ImageFallbackActions> createState() => _ImageFallbackActionsState();
}

class _ImageFallbackActionsState extends State<_ImageFallbackActions> {
  bool _copied = false;
  Timer? _resetCopied;

  @override
  void dispose() {
    _resetCopied?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetCopied?.cancel();
    _resetCopied = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FallbackChip(
            icon: _copied ? Icons.check : Icons.link,
            label: _copied ? l.linkCopied : l.copyLink,
            onTap: _copy,
          ),
          if (widget.onOpen != null) ...[
            Container(width: 1, height: 16, color: context.colors.border),
            _FallbackChip(
              icon: Icons.open_in_new,
              label: l.openImageInBrowser,
              onTap: () => widget.onOpen!(widget.url),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tappable action in the image-fallback bar (an accent icon + label).
class _FallbackChip extends StatelessWidget {
  const _FallbackChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.md,
          vertical: context.spacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c.accent, size: 16),
            SizedBox(width: context.spacing.xs),
            Flexible(
              child: Text(
                label,
                style: context.typography.bodySm.copyWith(color: c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

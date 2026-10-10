import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Loads the bytes for an inline image URL (e.g. via an authenticated client).
typedef ImageBytesLoader = Future<Uint8List?> Function(String url);

/// Resolves an inline image [url] to an absolute link that can be copied or
/// opened in a browser, or null if it can't be resolved.
typedef ImageUrlResolver = String? Function(String url);

/// Opens an already-resolved image [url] externally (in a browser).
typedef ImageExternalOpener = Future<void> Function(String url);

/// An inline image in a description or comment (Markdown or HTML), fetched
/// through [ImageBytesLoader] (memoized so it isn't refetched on every
/// rebuild), with loading / broken states.
class InlineImage extends StatefulWidget {
  const InlineImage({
    super.key,
    required this.url,
    required this.loader,
    this.fallbackUrl,
    this.onOpenImage,
    this.width,
    this.padding,
  });

  final String url;
  final ImageBytesLoader loader;
  final ImageUrlResolver? fallbackUrl;
  final ImageExternalOpener? onOpenImage;
  final double? width;

  /// Space around the image; a little above and below by default.
  final EdgeInsets? padding;

  @override
  State<InlineImage> createState() => InlineImageState();
}

class InlineImageState extends State<InlineImage> {
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
              Icon(LucideIcons.imageOff300, color: c.textTertiary, size: 22),
            );
          }
          return _frame(
            context,
            _ImageFallbackActions(url: resolved, onOpen: widget.onOpenImage),
          );
        }
        return Container(
          padding:
              widget.padding ??
              EdgeInsets.symmetric(vertical: context.spacing.sm),
          // A chosen width is honoured as is; otherwise tall images are capped.
          constraints: widget.width == null
              ? const BoxConstraints(maxHeight: 400)
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.radii.md),
            child: Image.memory(
              bytes,
              width: widget.width,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _frame(
                context,
                Icon(LucideIcons.imageOff300, color: c.textTertiary),
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
/// [InlineImage.fallbackUrl]). Copy shows a transient "copied" state.
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
            icon: _copied ? LucideIcons.check300 : LucideIcons.link300,
            label: _copied ? l.linkCopied : l.copyLink,
            onTap: _copy,
          ),
          if (widget.onOpen != null) ...[
            Container(width: 1, height: 16, color: context.colors.border),
            _FallbackChip(
              icon: LucideIcons.squareArrowOutUpRight300,
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
      mouseCursor: WidgetStateMouseCursor.clickable,
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

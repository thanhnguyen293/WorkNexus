import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_labels.dart';
import 'chat_media_viewer_bar.dart';

/// The image viewer's picture area: the image, zoomed and panned through
/// [transform] and turned [turns] quarter turns, with the download's
/// progress or an error over it and previous/next arrows on its sides.
class ChatImageStage extends StatelessWidget {
  const ChatImageStage({
    super.key,
    required this.transform,
    required this.bytes,
    required this.originalSize,
    required this.turns,
    required this.minScale,
    required this.maxScale,
    required this.roomForArrows,
    required this.loading,
    required this.progress,
    required this.totalBytes,
    required this.failed,
    required this.onDoubleTap,
    required this.onPrevious,
    required this.onNext,
    this.onContextMenu,
  });

  final TransformationController transform;

  /// The best copy so far (the preview until the original arrives).
  final Uint8List? bytes;

  /// The original's pixel size when the message says it: the preview is
  /// drawn at that size, so it sits exactly where the original will.
  final Size? originalSize;
  final int turns;
  final double minScale;
  final double maxScale;

  /// Keeps the fitted image clear of the side arrows.
  final bool roomForArrows;
  final bool loading;

  /// Share of the original downloaded (0–1); null before the first bytes.
  final double? progress;

  /// The original's size in bytes; 0 when unknown.
  final int totalBytes;
  final bool failed;
  final VoidCallback onDoubleTap;

  /// Null hides the arrow (first / last image).
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Right-click on the picture, with the pointer's global position.
  final void Function(Offset at)? onContextMenu;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final image = bytes;
    final original = originalSize;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: onDoubleTap,
            onSecondaryTapUp: onContextMenu == null
                ? null
                : (d) => onContextMenu?.call(d.globalPosition),
            child: InteractiveViewer(
              transformationController: transform,
              minScale: minScale,
              maxScale: maxScale,
              boundaryMargin: EdgeInsets.all(s.xl6 * 10),
              // Fitted, the image stays clear of the side arrows; zoomed, it
              // may use the whole area.
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: roomForArrows ? s.xl6 * 2 : s.xl3,
                  vertical: s.xl3,
                ),
                child: Center(
                  child: image == null
                      ? const SizedBox.shrink()
                      : RotatedBox(
                          quarterTurns: turns,
                          child: original == null
                              ? Image.memory(image, gaplessPlayback: true)
                              // Shrunk to fit like the original would be,
                              // never blown up past it.
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox.fromSize(
                                    size: original,
                                    child: Image.memory(
                                      image,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                ),
                        ),
                ),
              ),
            ),
          ),
        ),
        if (loading || failed)
          Center(
            child: failed
                ? Text(
                    l.chatAttachmentFailed,
                    style: context.typography.body.copyWith(color: c.onScrim),
                  )
                : _DownloadProgress(progress: progress, total: totalBytes),
          ),
        if (onPrevious case final previous?)
          ChatViewerSideArrow(
            alignment: Alignment.centerLeft,
            icon: LucideIcons.chevronLeft300,
            tooltip: l.chatPrevious,
            onPressed: previous,
          ),
        if (onNext case final next?)
          ChatViewerSideArrow(
            alignment: Alignment.centerRight,
            icon: LucideIcons.chevronRight300,
            tooltip: l.chatNext,
            onPressed: next,
          ),
      ],
    );
  }
}

/// How much of the original has arrived: a ring filling up with the share,
/// and "received / total" under it when the size is known.
class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress, required this.total});

  final double? progress;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final done = progress;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.scrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.xl3, vertical: s.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: s.xl6,
              child: CircularProgressIndicator(
                // Spins until the first bytes say how far along it is.
                value: done,
                color: c.onScrim,
                backgroundColor: c.onScrim.withValues(alpha: 0.2),
              ),
            ),
            if (total > 0) ...[
              SizedBox(height: s.md),
              Text(
                '${formatFileSize(((done ?? 0) * total).round())} / '
                '${formatFileSize(total)}',
                style: context.typography.secondary.copyWith(
                  color: c.onScrim,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_media_viewer_bar.dart';

/// The image viewer's picture area: the image, zoomed and panned through
/// [transform] and turned [turns] quarter turns, with a spinner or an error
/// over it and previous/next arrows on its sides.
class ChatImageStage extends StatelessWidget {
  const ChatImageStage({
    super.key,
    required this.transform,
    required this.bytes,
    required this.turns,
    required this.minScale,
    required this.maxScale,
    required this.roomForArrows,
    required this.loading,
    required this.failed,
    required this.onDoubleTap,
    required this.onPrevious,
    required this.onNext,
  });

  final TransformationController transform;

  /// The best copy so far (the preview until the original arrives).
  final Uint8List? bytes;
  final int turns;
  final double minScale;
  final double maxScale;

  /// Keeps the fitted image clear of the side arrows.
  final bool roomForArrows;
  final bool loading;
  final bool failed;
  final VoidCallback onDoubleTap;

  /// Null hides the arrow (first / last image).
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final image = bytes;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: onDoubleTap,
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
                          child: Image.memory(image, gaplessPlayback: true),
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
                : CircularProgressIndicator(color: c.onScrim),
          ),
        if (onPrevious case final previous?)
          ChatViewerSideArrow(
            alignment: Alignment.centerLeft,
            icon: PhosphorIconsLight.caretLeft,
            tooltip: l.chatPrevious,
            onPressed: previous,
          ),
        if (onNext case final next?)
          ChatViewerSideArrow(
            alignment: Alignment.centerRight,
            icon: PhosphorIconsLight.caretRight,
            tooltip: l.chatNext,
            onPressed: next,
          ),
      ],
    );
  }
}

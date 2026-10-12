import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_icon_button.dart';
import 'inline_image.dart';

/// An image from a description or comment, enlarged over the app: zoom with
/// the wheel or a pinch, drag to pan, double-click to zoom in or back to fit.
/// Esc, the close button or a click beside the image closes it.
class ImageViewerDialog extends StatefulWidget {
  const ImageViewerDialog({
    super.key,
    required this.bytes,
    this.externalUrl,
    this.onOpenExternally,
  });

  final Uint8List bytes;

  /// Where the image lives, for "open in browser"; null hides that action.
  final String? externalUrl;
  final ImageExternalOpener? onOpenExternally;

  static Future<void> show(
    BuildContext context, {
    required Uint8List bytes,
    String? externalUrl,
    ImageExternalOpener? onOpenExternally,
  }) => showDialog<void>(
    context: context,
    barrierColor: context.colors.scrim.withValues(alpha: _barrierAlpha),
    builder: (_) => ImageViewerDialog(
      bytes: bytes,
      externalUrl: externalUrl,
      onOpenExternally: onOpenExternally,
    ),
  );

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

/// Dark enough that the image, not the ticket behind it, holds the eye.
const _barrierAlpha = 0.85;

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  static const _minScale = 0.5;
  static const _maxScale = 8.0;

  /// How far a double-click zooms in from fit.
  static const _doubleTapScale = 2.5;

  final _transform = TransformationController();
  Offset? _doubleTapAt;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _toggleZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    final at = _doubleTapAt;
    if (zoomed || at == null) {
      _transform.value = Matrix4.identity();
      return;
    }
    // Zoom about the clicked point, so what was clicked stays under it.
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -at.dx * (_doubleTapScale - 1),
        -at.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final url = widget.externalUrl;
    final open = widget.onOpenExternally;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            // A click beside the image closes; on it, nothing happens.
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: _minScale,
              maxScale: _maxScale,
              boundaryMargin: EdgeInsets.all(s.xl6 * 4),
              // Double-clicks are read in the viewer's own space, which is
              // what the zoom transforms.
              child: GestureDetector(
                onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                onDoubleTap: _toggleZoom,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(s.xl6),
                    child: GestureDetector(
                      onTap: () {},
                      child: Image.memory(widget.bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: s.xl,
          right: s.xl,
          child: Material(
            color: c.card,
            shape: const StadiumBorder(),
            child: Padding(
              padding: EdgeInsets.all(s.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (url != null && open != null)
                    AppIconButton(
                      icon: LucideIcons.squareArrowOutUpRight300,
                      tooltip: l.openImageInBrowser,
                      onPressed: () => open(url),
                    ),
                  AppIconButton(
                    icon: LucideIcons.x300,
                    tooltip: l.close,
                    onPressed: _close,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

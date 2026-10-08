import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_labels.dart';

/// The image viewer's top bar: name, size and position on the left; zoom,
/// fit, rotate, copy, save, open-with and close on the right.
class ChatImageViewerBar extends StatelessWidget {
  const ChatImageViewerBar({
    super.key,
    required this.image,
    required this.position,
    required this.transform,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onRotate,
    required this.onCopy,
    required this.onSave,
    required this.onOpenExternally,
    required this.onClose,
  });

  final ImageContent image;

  /// "3 / 12" within the chat's images.
  final String position;
  final TransformationController transform;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onRotate;

  /// Null until the original has loaded.
  final VoidCallback? onCopy;
  final VoidCallback onSave;
  final VoidCallback onOpenExternally;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final ink = c.onScrim;
    final dims = image.width != null && image.height != null
        ? '${image.width}×${image.height}'
        : null;
    final meta = [
      position,
      if (image.size > 0) formatFileSize(image.size),
      ?dims,
    ].join('   ');
    Widget button(IconData icon, String tooltip, VoidCallback? onPressed) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          color: ink,
          disabledColor: ink.withValues(alpha: 0.35),
          icon: Icon(icon),
        );

    return DecoratedBox(
      decoration: BoxDecoration(color: c.scrim.withValues(alpha: 0.55)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.xl3, vertical: s.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    image.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodyStrong.copyWith(color: ink),
                  ),
                  Text(
                    meta,
                    style: context.typography.caption.copyWith(
                      color: ink.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            button(Icons.zoom_out_rounded, l.chatZoomOut, onZoomOut),
            ValueListenableBuilder(
              valueListenable: transform,
              builder: (context, matrix, _) => SizedBox(
                width: s.xl6 * 1.4,
                child: Text(
                  '${(matrix.getMaxScaleOnAxis() * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: context.typography.captionStrong.copyWith(color: ink),
                ),
              ),
            ),
            button(Icons.zoom_in_rounded, l.chatZoomIn, onZoomIn),
            button(Icons.fit_screen_outlined, l.chatZoomFit, onFit),
            button(Icons.rotate_right_rounded, l.chatRotate, onRotate),
            SizedBox(width: s.md),
            button(Icons.copy_rounded, l.chatCopyImage, onCopy),
            button(Icons.download_rounded, l.chatSaveAs, onSave),
            button(Icons.open_in_new_rounded, l.chatOpenWith, onOpenExternally),
            SizedBox(width: s.md),
            button(Icons.close_rounded, l.chatClosePanel, onClose),
          ],
        ),
      ),
    );
  }
}

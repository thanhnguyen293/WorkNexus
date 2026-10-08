import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_labels.dart';
import 'chat_media_viewer_bar.dart';

/// The image viewer's top bar: name, position, size and dimensions; zoom,
/// fit, rotate, copy, save, save as sticker, open-with and close.
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
    required this.onSaveSticker,
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

  /// Keeps the image as a sticker; null once it was saved.
  final VoidCallback? onSaveSticker;
  final VoidCallback onOpenExternally;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final w = image.width;
    final h = image.height;
    return ChatMediaViewerBar(
      title: image.name,
      details: [
        position,
        if (image.size > 0) formatFileSize(image.size),
        if (w != null && h != null) '$w×$h',
      ],
      onClose: onClose,
      actions: [
        ChatViewerButton(
          icon: Icons.zoom_out_rounded,
          tooltip: l.chatZoomOut,
          onPressed: onZoomOut,
        ),
        ValueListenableBuilder(
          valueListenable: transform,
          builder: (context, matrix, _) => SizedBox(
            width: s.xl6 * 1.4,
            child: Text(
              '${(matrix.getMaxScaleOnAxis() * 100).round()}%',
              textAlign: TextAlign.center,
              style: context.typography.captionStrong.copyWith(
                color: context.colors.onScrim,
              ),
            ),
          ),
        ),
        ChatViewerButton(
          icon: Icons.zoom_in_rounded,
          tooltip: l.chatZoomIn,
          onPressed: onZoomIn,
        ),
        ChatViewerButton(
          icon: Icons.fit_screen_outlined,
          tooltip: l.chatZoomFit,
          onPressed: onFit,
        ),
        ChatViewerButton(
          icon: Icons.rotate_right_rounded,
          tooltip: l.chatRotate,
          onPressed: onRotate,
        ),
        SizedBox(width: s.md),
        ChatViewerButton(
          icon: Icons.copy_rounded,
          tooltip: l.chatCopyImage,
          onPressed: onCopy,
        ),
        ChatViewerButton(
          icon: Icons.download_rounded,
          tooltip: l.chatSaveAs,
          onPressed: onSave,
        ),
        ChatViewerButton(
          icon: onSaveSticker == null
              ? Icons.check_rounded
              : Icons.add_reaction_outlined,
          tooltip: onSaveSticker == null
              ? l.chatStickerSaved
              : l.chatSaveSticker,
          onPressed: onSaveSticker,
        ),
        ChatViewerButton(
          icon: Icons.open_in_new_rounded,
          tooltip: l.chatOpenWith,
          onPressed: onOpenExternally,
        ),
      ],
    );
  }
}

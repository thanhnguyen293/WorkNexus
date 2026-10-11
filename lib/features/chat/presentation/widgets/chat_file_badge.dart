import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_labels.dart';

/// A file's extension on an accent square. While the file moves ([busy]) a
/// translucent ring over it fills with [progress] (spins when unknown), the
/// extension still showing through; hovering then swaps both for a ✕ that
/// calls [onCancel].
class ChatFileBadge extends StatelessWidget {
  const ChatFileBadge({
    super.key,
    required this.fileName,
    required this.busy,
    this.progress,
    this.onCancel,
    this.cancelTooltip,
  });

  final String fileName;
  final bool busy;
  final double? progress;
  final VoidCallback? onCancel;

  /// Defaults to "Cancel download".
  final String? cancelTooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final cancellable = busy && onCancel != null;
    return HoverRegion(
      enabled: cancellable,
      builder: (context, hovered, _) {
        final Widget content;
        if (hovered) {
          content = Icon(LucideIcons.x300, size: s.xl4, color: c.onAccent);
        } else {
          content = Stack(
            alignment: Alignment.center,
            children: [
              Text(
                chatFileBadge(fileName),
                style: context.typography.captionStrong.copyWith(
                  color: c.onAccent,
                ),
              ),
              if (busy)
                SizedBox.square(
                  dimension: s.xl6 - s.md,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
                    color: c.onAccent.withValues(alpha: 0.6),
                    backgroundColor: c.onAccent.withValues(alpha: 0.15),
                  ),
                ),
            ],
          );
        }
        final badge = HoverSurface(
          width: s.xl6,
          height: s.xl6,
          color: c.accent,
          hoverColor: c.onAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(context.radii.md),
          onTap: cancellable ? onCancel : null,
          child: Center(child: content),
        );
        return cancellable
            ? Tooltip(
                message:
                    cancelTooltip ?? AppL10n.of(context).chatCancelDownload,
                child: badge,
              )
            : badge;
      },
    );
  }
}

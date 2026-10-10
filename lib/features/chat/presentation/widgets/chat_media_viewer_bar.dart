import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Top bar of the image and video viewers: name and details on the left,
/// [actions] and close on the right.
class ChatMediaViewerBar extends StatelessWidget {
  const ChatMediaViewerBar({
    super.key,
    required this.title,
    required this.details,
    required this.actions,
    required this.onClose,
  });

  final String title;

  /// Position, size, dimensions… joined on one line.
  final List<String> details;
  final List<Widget> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final ink = c.onScrim;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.scrim.withValues(alpha: 0.6)),
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodyStrong.copyWith(color: ink),
                  ),
                  Text(
                    details.join('   '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption.copyWith(
                      color: ink.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            ...actions,
            SizedBox(width: s.md),
            ChatViewerButton(
              icon: LucideIcons.x300,
              tooltip: AppL10n.of(context).chatClosePanel,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon button in the viewers' light-on-dark style.
class ChatViewerButton extends StatelessWidget {
  const ChatViewerButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Toggled on (e.g. loop): drawn in the accent colour.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      iconSize: context.spacing.xl4,
      color: selected ? c.accent : c.onScrim,
      disabledColor: c.onScrim.withValues(alpha: 0.35),
      icon: Icon(icon),
    );
  }
}

/// A short vertical rule between groups of viewer buttons.
class ChatViewerDivider extends StatelessWidget {
  const ChatViewerDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Container(
      width: 1,
      height: s.xl4,
      margin: EdgeInsets.symmetric(horizontal: s.md),
      color: context.colors.onScrim.withValues(alpha: 0.25),
    );
  }
}

/// A round previous/next button on the viewer's left or right edge.
class ChatViewerSideArrow extends StatelessWidget {
  const ChatViewerSideArrow({
    super.key,
    required this.alignment,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Alignment alignment;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl4),
        child: IconButton.filled(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: c.scrim.withValues(alpha: 0.5),
            foregroundColor: c.onScrim,
          ),
          iconSize: context.spacing.xl6 * 0.8,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

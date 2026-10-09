import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/unread_badge.dart';
import '../../../../l10n/app_localizations.dart';

const Duration _kDuration = Duration(milliseconds: 200);

/// Round button over the bottom of the messages while the user has scrolled
/// up: jumps back to the newest message. [unseen] counts messages that
/// arrived since they scrolled away, shown as a badge on the button.
class ScrollToLatestButton extends StatelessWidget {
  const ScrollToLatestButton({
    super.key,
    required this.visible,
    required this.unseen,
    required this.onPressed,
  });

  /// Scales in and out as the user leaves and returns to the bottom.
  final bool visible;
  final int unseen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final button = Tooltip(
      message: unseen > 0 ? l.chatNewMessages(unseen) : l.chatScrollToLatest,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: c.surface,
            elevation: s.xs,
            shadowColor: c.scrim,
            shape: CircleBorder(side: BorderSide(color: c.border)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: s.xl6,
                child: Icon(
                  PhosphorIconsLight.caretDoubleDown,
                  color: unseen > 0 ? c.accent : c.textSecondary,
                ),
              ),
            ),
          ),
          if (unseen > 0)
            Positioned(
              top: -s.sm,
              left: 0,
              right: 0,
              child: Center(child: UnreadBadge(count: unseen)),
            ),
        ],
      ),
    );
    return AnimatedSwitcher(
      duration: _kDuration,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: visible ? button : const SizedBox.shrink(),
    );
  }
}

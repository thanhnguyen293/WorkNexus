import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// One hover action on a message.
typedef MessageAction = ({IconData icon, String tooltip, VoidCallback onTap});

/// A small toolbar floating over the top corner of [child] while the pointer
/// is over the message. It overlays rather than takes space, so messages keep
/// their width and nothing shifts on hover.
class MessageHoverActions extends StatefulWidget {
  const MessageHoverActions({
    super.key,
    required this.child,
    required this.actions,
    required this.alignEnd,
  });

  final Widget child;
  final List<MessageAction> actions;

  /// Own messages (right side) get the toolbar on their left corner.
  final bool alignEnd;

  @override
  State<MessageHoverActions> createState() => _MessageHoverActionsState();
}

class _MessageHoverActionsState extends State<MessageHoverActions> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return widget.child;
    final c = context.colors;
    final s = context.spacing;
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in widget.actions)
            Tooltip(
              message: a.tooltip,
              child: InkWell(
                onTap: a.onTap,
                borderRadius: BorderRadius.circular(context.radii.sm),
                child: Padding(
                  padding: EdgeInsets.all(s.sm),
                  child: Icon(a.icon, size: s.xl3, color: c.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            top: -s.xl3,
            right: widget.alignEnd ? null : -s.xl,
            left: widget.alignEnd ? -s.xl : null,
            child: AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: const Duration(milliseconds: 100),
              child: IgnorePointer(ignoring: !_hover, child: bar),
            ),
          ),
        ],
      ),
    );
  }
}

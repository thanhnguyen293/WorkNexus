import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'message_context_menu.dart';

/// One action on a message, offered on hover and in its right-click menu.
/// [destructive] ones (retract) are shown last, in the error colour.
typedef MessageAction = ({
  IconData icon,
  String tooltip,
  VoidCallback onTap,
  bool destructive,
});

/// Zalo-style message actions: round buttons beside the bubble, level with
/// its bottom edge, shown while the pointer is over the message — the
/// first actions (reply, open thread) as buttons, the rest under "…". They sit in
/// the bubble's row (outside the bubble, so they are clickable), keeping
/// their space while hidden so nothing shifts on hover.
class MessageHoverActions extends StatefulWidget {
  const MessageHoverActions({
    super.key,
    required this.child,
    required this.actions,
    required this.alignEnd,
    this.buttons = 1,
  });

  final Widget child;
  final List<MessageAction> actions;

  /// How many leading actions get a button of their own; the rest go under
  /// "…".
  final int buttons;

  /// Own messages (right side) get the buttons on their left.
  final bool alignEnd;

  @override
  State<MessageHoverActions> createState() => _MessageHoverActionsState();
}

class _MessageHoverActionsState extends State<MessageHoverActions> {
  bool _hover = false;

  /// Keeps the buttons up while the "…" menu is open.
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    if (actions.isEmpty) return widget.child;
    final s = context.spacing;
    final own = actions.take(widget.buttons).toList();
    final rest = actions.skip(widget.buttons).toList();
    final buttons = AnimatedOpacity(
      opacity: _hover || _menuOpen ? 1 : 0,
      duration: const Duration(milliseconds: 100),
      child: IgnorePointer(
        ignoring: !(_hover || _menuOpen),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, a) in own.indexed) ...[
                if (i > 0) SizedBox(width: s.sm),
                _RoundButton(icon: a.icon, tooltip: a.tooltip, onTap: a.onTap),
              ],
              if (rest.isNotEmpty) ...[
                SizedBox(width: s.sm),
                _MoreButton(onOpen: (at) => _openMenu(rest, at)),
              ],
            ],
          ),
        ),
      ),
    );
    final bubble = GestureDetector(
      onSecondaryTapDown: (d) => _openMenu(widget.actions, d.globalPosition),
      child: widget.child,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: widget.alignEnd
            ? [buttons, Flexible(child: bubble)]
            : [Flexible(child: bubble), buttons],
      ),
    );
  }

  /// Keeps the hover buttons up while a menu of [actions] is open at [at].
  Future<void> _openMenu(List<MessageAction> actions, Offset at) async {
    setState(() => _menuOpen = true);
    await showMessageContextMenu(context, actions: actions, at: at);
    if (mounted) setState(() => _menuOpen = false);
  }
}

/// A round button in the surface colour with a hairline border.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;

  /// Null when an enclosing widget shows the tooltip.
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final button = Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: s.xl6 * 0.8,
          child: Icon(icon, size: s.xl3, color: c.textSecondary),
        ),
      ),
    );
    final message = tooltip;
    return message == null ? button : Tooltip(message: message, child: button);
  }
}

/// "…": opens the remaining actions as a menu just below the button.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onOpen});

  final void Function(Offset at) onOpen;

  @override
  Widget build(BuildContext context) {
    return _RoundButton(
      icon: PhosphorIconsLight.dotsThree,
      tooltip: AppL10n.of(context).chatMoreActions,
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        onOpen(
          box.localToGlobal(Offset(0, box.size.height + context.spacing.xs)),
        );
      },
    );
  }
}

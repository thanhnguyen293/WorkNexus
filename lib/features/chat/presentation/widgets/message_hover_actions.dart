import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
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
    this.onReact,
  });

  final Widget child;
  final List<MessageAction> actions;

  /// How many leading actions get a button of their own; the rest go under
  /// "…".
  final int buttons;

  /// Own messages (right side) get the buttons on their left.
  final bool alignEnd;

  /// Reacts to the message: a "React" entry in the menus, given where the
  /// menu opened (global) so the choice of emoji opens right there. Null: the
  /// message cannot be reacted to.
  final void Function(Offset anchor)? onReact;

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
    final isVisible = _hover || _menuOpen;
    final buttons = Opacity(
      opacity: isVisible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, a) in own.indexed) ...[
                if (i > 0) SizedBox(width: s.sm),
                _RoundButton(icon: a.icon, tooltip: a.tooltip, onTap: a.onTap),
              ],
              if (rest.isNotEmpty || widget.onReact != null) ...[
                SizedBox(width: s.sm),
                _MoreButton(onOpen: (at) => _openMenu(rest, at)),
              ],
            ],
          ),
        ),
      ),
    );
    // A raw pointer listener, not a tap recogniser: selectable message text
    // takes part in the gesture arena (it has its own secondary tap) and
    // would win a right-click on the text.
    final bubble = Listener(
      onPointerDown: (e) {
        if (e.buttons & kSecondaryMouseButton != 0) {
          _openMenu(widget.actions, e.position);
        }
      },
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
    final react = widget.onReact;
    final withReact = [
      if (react != null)
        (
          icon: LucideIcons.smilePlus300,
          tooltip: AppL10n.of(context).chatReact,
          destructive: false,
          onTap: () => react(at),
        ),
      ...actions,
    ];
    await showMessageContextMenu(context, actions: withReact, at: at);
    if (mounted) setState(() => _menuOpen = false);
  }
}

/// A round button in the surface colour with a hairline border. Not
/// `AppIconButton`: it floats over the chat wallpaper, so it needs its own
/// opaque disc to stay legible.
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
    final button = Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: context.sizes.controlMd,
          child: Icon(icon, size: context.sizes.iconMd, color: c.textSecondary),
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
      icon: LucideIcons.ellipsis300,
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

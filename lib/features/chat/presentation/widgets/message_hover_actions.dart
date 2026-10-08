import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// One hover action on a message.
typedef MessageAction = ({IconData icon, String tooltip, VoidCallback onTap});

/// Zalo-style message actions: round buttons beside the bubble, level with
/// its bottom edge, shown while the pointer is over the message — the
/// first action (reply) as its own button, the rest under "…". They sit in
/// the bubble's row (outside the bubble, so they are clickable), keeping
/// their space while hidden so nothing shifts on hover.
class MessageHoverActions extends StatefulWidget {
  const MessageHoverActions({
    super.key,
    required this.child,
    required this.actions,
    required this.alignEnd,
  });

  final Widget child;
  final List<MessageAction> actions;

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
    final first = actions.first;
    final rest = actions.skip(1).toList();
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
              _RoundButton(
                icon: first.icon,
                tooltip: first.tooltip,
                onTap: first.onTap,
              ),
              if (rest.isNotEmpty) ...[
                SizedBox(width: s.sm),
                _MoreButton(
                  actions: rest,
                  onOpen: () => setState(() => _menuOpen = true),
                  onClose: () => setState(() => _menuOpen = false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: widget.alignEnd
            ? [buttons, Flexible(child: widget.child)]
            : [Flexible(child: widget.child), buttons],
      ),
    );
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

/// "…": the remaining actions as a menu.
class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.actions,
    required this.onOpen,
    required this.onClose,
  });

  final List<MessageAction> actions;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<int>(
      tooltip: AppL10n.of(context).chatMoreActions,
      onOpened: onOpen,
      onCanceled: onClose,
      onSelected: (i) {
        onClose();
        actions[i].onTap();
      },
      itemBuilder: (_) => [
        for (final (i, a) in actions.indexed)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(a.icon, size: context.spacing.xl4, color: c.textSecondary),
                SizedBox(width: context.spacing.lg),
                Text(
                  a.tooltip,
                  style: context.typography.body.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
      ],
      child: const IgnorePointer(
        child: _RoundButton(
          icon: Icons.more_horiz_rounded,
          tooltip: null,
          onTap: null,
        ),
      ),
    );
  }
}

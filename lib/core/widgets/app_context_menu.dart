import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// One row of an [showAppContextMenu].
class AppMenuEntry {
  const AppMenuEntry({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.dividerBefore = false,
  });

  final IconData icon;
  final String label;

  /// Drawn in the error colour (delete, retract, remove).
  final bool destructive;

  /// A hairline separates this row from the one above.
  final bool dividerBefore;
}

/// Opens a desktop context menu with its top-left corner at [at] (global),
/// flipped to stay on screen, and resolves to the picked entry's index, or
/// null when dismissed (click outside / Esc).
///
/// A custom route rather than `showMenu`: the Material menu's 48px rows and
/// slow grow animation read as sluggish for a desktop context menu.
Future<int?> showAppContextMenu(
  BuildContext context, {
  required Offset at,
  required List<AppMenuEntry> entries,
}) {
  final navigator = Navigator.of(context);
  final box = navigator.context.findRenderObject() as RenderBox?;
  return navigator.push(
    _ContextMenuRoute(
      entries: entries,
      anchor: box?.globalToLocal(at) ?? at,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _ContextMenuRoute extends PopupRoute<int> {
  _ContextMenuRoute({
    required this.entries,
    required this.anchor,
    required this.barrierLabel,
  });

  final List<AppMenuEntry> entries;
  final Offset anchor;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 80);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return CustomSingleChildLayout(
      delegate: _MenuLayout(anchor, margin: context.spacing.md),
      child: AppMenuPanel(
        entries: entries,
        onSelected: (i) => Navigator.of(context).pop(i),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        alignment: Alignment.topLeft,
        child: child,
      ),
    );
  }
}

/// Puts the menu at the anchor, opening up / left instead when it would
/// run past the bottom / right edge.
class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(this.anchor, {required this.margin});

  final Offset anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(EdgeInsets.all(margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = anchor.dx;
    var y = anchor.dy;
    if (x + childSize.width > size.width - margin) x -= childSize.width;
    if (y + childSize.height > size.height - margin) y -= childSize.height;
    return Offset(
      x.clamp(margin, size.width - childSize.width - margin),
      y.clamp(margin, size.height - childSize.height - margin),
    );
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      anchor != old.anchor || margin != old.margin;
}

/// The app's menu card: [entries] as compact rows on a raised panel. Shown
/// by [showAppContextMenu], and usable as a [MenuAnchor]'s only child for a
/// menu anchored to a button.
class AppMenuPanel extends StatelessWidget {
  const AppMenuPanel({
    required this.entries,
    required this.onSelected,
    super.key,
  });

  final List<AppMenuEntry> entries;

  /// Called with the picked entry's index.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return IntrinsicWidth(
      child: Container(
        constraints: BoxConstraints(minWidth: s.xl6 * 5),
        padding: EdgeInsets.all(s.xs),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(context.radii.lg),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.scrim.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, e) in entries.indexed) ...[
                if (i > 0 && e.dividerBefore)
                  Container(
                    height: 1,
                    margin: EdgeInsets.symmetric(
                      horizontal: s.md,
                      vertical: s.xs,
                    ),
                    color: c.border,
                  ),
                _MenuItem(entry: e, onTap: () => onSelected(i)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.entry, required this.onTap});

  final AppMenuEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final tint = entry.destructive ? c.error : null;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      hoverColor: (tint ?? c.textPrimary).withValues(alpha: 0.08),
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.md),
        child: Row(
          children: [
            Icon(entry.icon, size: s.xl3, color: tint ?? c.textSecondary),
            SizedBox(width: s.lg),
            Text(
              entry.label,
              style: context.typography.body.copyWith(
                color: tint ?? c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

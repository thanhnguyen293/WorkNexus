import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A navigation pane folded to a thin strip beside the rail: hovering the
/// strip opens the pane over the viewport, leaving it closes it again (not
/// while something in it has focus — typing in its filter). The viewport
/// keeps its width throughout, so a long page isn't laid out again.
///
/// The pane stays mounted while folded (offstage in the overlay), so it
/// keeps its scroll position and state.
class AutoHidePane extends StatefulWidget {
  const AutoHidePane({
    super.key,
    required this.child,
    required this.icon,
    required this.label,
  });

  final Widget child;

  /// What the folded strip shows, as a rail button does: the pane's place.
  final IconData icon;
  final String label;

  @override
  State<AutoHidePane> createState() => _AutoHidePaneState();
}

class _AutoHidePaneState extends State<AutoHidePane>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _height = ValueNotifier<double>(0);
  bool _open = false;
  bool _focused = false;
  Timer? _timer;

  /// A pass of the pointer across the strip doesn't open the pane.
  static const _openDelay = Duration(milliseconds: 120);

  /// Crossing the gap between strip and pane doesn't close it.
  static const _closeDelay = Duration(milliseconds: 280);

  /// The pane eases in from just behind the strip, and out a little faster.
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 140),
  )..addStatusListener((_) => setState(() {}));
  late final _eased = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final _slide = Tween(
    begin: const Offset(-0.06, 0),
    end: Offset.zero,
  ).animate(_eased);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _height.dispose();
    _eased.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _hover(bool inside) {
    _timer?.cancel();
    if (inside) {
      if (!_open) _timer = Timer(_openDelay, () => _setOpen(true));
    } else {
      _timer = Timer(_closeDelay, () {
        if (!_focused) _setOpen(false);
      });
    }
  }

  void _setOpen(bool open) {
    if (!mounted || _open == open) return;
    setState(() => _open = open);
    // Reduced motion: the pane appears and goes at once.
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = open ? 1 : 0;
    } else if (open) {
      _motion.forward();
    } else {
      _motion.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final edge = BorderSide(color: c.border, width: context.borders.hairline);
    // A place kept alive offstage (another one on screen) never shows it;
    // closing, the pane stays on stage until its motion has played out.
    final active = TickerMode.valuesOf(context).enabled;
    final shown = active && !_motion.isDismissed;

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<double>(
            valueListenable: _height,
            builder: (context, height, child) =>
                SizedBox(height: height, child: child),
            child: Offstage(
              offstage: !shown,
              child: TickerMode(
                enabled: shown,
                child: IgnorePointer(
                  ignoring: !_open,
                  child: FadeTransition(
                    opacity: _eased,
                    child: SlideTransition(
                      position: _slide,
                      child: MouseRegion(
                        onEnter: (_) => _hover(true),
                        onExit: (_) => _hover(false),
                        child: Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          onFocusChange: (focused) {
                            _focused = focused;
                            if (!focused) _hover(false);
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.surface,
                              border: Border(right: edge),
                              boxShadow: [
                                BoxShadow(
                                  color: c.scrim.withValues(alpha: 0.18),
                                  blurRadius: s.xl5,
                                  offset: Offset(s.xs, 0),
                                ),
                              ],
                            ),
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          onEnter: (_) => _hover(true),
          onExit: (_) => _hover(false),
          child: LayoutBuilder(
            builder: (context, box) {
              if (_height.value != box.maxHeight) {
                // The pane opens as tall as the strip.
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _height.value = box.maxHeight,
                );
              }
              // As wide as the rail, read like one of its buttons.
              return Container(
                width: context.sizes.railWidth,
                padding: EdgeInsets.fromLTRB(s.xs, s.xl, s.xs, 0),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(right: edge),
                ),
                child: Column(
                  children: [
                    Icon(
                      widget.icon,
                      size: context.sizes.iconLg,
                      color: c.textSecondary,
                    ),
                    SizedBox(height: s.xs),
                    Text(
                      widget.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    SizedBox(height: s.sm),
                    Icon(
                      LucideIcons.panelLeftOpen300,
                      size: context.sizes.iconSm,
                      color: c.textTertiary,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

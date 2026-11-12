import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_toast_controller.dart';

/// How long a toast stays up: the more it needs reading, the longer.
Duration _showFor(AppToastKind kind) => switch (kind) {
  AppToastKind.success => const Duration(milliseconds: 2500),
  AppToastKind.warning => const Duration(seconds: 4),
  AppToastKind.error => const Duration(seconds: 5),
};
const _kAppear = Duration(milliseconds: 150);

/// A compact toast: a card (app radius) with a status glyph and the message. It slides in,
/// goes away by itself (held while the pointer is on it), and a click
/// dismisses it. A warning or an error is tinted in its colour and has a
/// close button.
class AppToastCard extends StatefulWidget {
  const AppToastCard({super.key, required this.toast, required this.onDismiss});

  final AppToast toast;
  final VoidCallback onDismiss;

  @override
  State<AppToastCard> createState() => _AppToastCardState();
}

class _AppToastCardState extends State<AppToastCard>
    with SingleTickerProviderStateMixin {
  late final _appear = AnimationController(vsync: this, duration: _kAppear)
    ..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer(_showFor(widget.toast.kind), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final kind = widget.toast.kind;
    final (glyph, tint) = switch (kind) {
      AppToastKind.success => (LucideIcons.circleCheck300, c.success),
      AppToastKind.warning => (LucideIcons.triangleAlert300, c.warning),
      AppToastKind.error => (LucideIcons.circleAlert300, c.error),
    };
    // A success stays plain; the others carry their colour and a close.
    final flagged = kind != AppToastKind.success;
    final radius = BorderRadius.circular(context.radii.md);
    final curved = CurvedAnimation(parent: _appear, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(curved),
        child: MouseRegion(
          onEnter: (_) => _timer?.cancel(),
          onExit: (_) => _start(),
          child: Material(
            color: flagged
                ? Color.alphaBlend(tint.withValues(alpha: 0.12), c.card)
                : c.card,
            elevation: 2,
            shadowColor: c.scrim,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: flagged ? tint.withValues(alpha: 0.4) : c.borderStrong,
              ),
            ),
            child: InkWell(
              borderRadius: radius,
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: widget.onDismiss,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  s.lg,
                  s.sm,
                  flagged ? s.sm : s.lg,
                  s.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: s.sm,
                  children: [
                    Icon(glyph, size: context.sizes.iconMd, color: tint),
                    Flexible(
                      child: Text(
                        widget.toast.message,
                        style: context.typography.body.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (flagged)
                      Semantics(
                        button: true,
                        label: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        child: Icon(
                          LucideIcons.x300,
                          size: context.sizes.iconSm,
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

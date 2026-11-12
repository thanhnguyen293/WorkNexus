import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_toast_controller.dart';

/// How long a toast stays up; an error longer, as it needs reading.
const _kShowFor = Duration(milliseconds: 2500);
const _kErrorShowFor = Duration(seconds: 5);
const _kAppear = Duration(milliseconds: 150);

/// A compact toast: a pill with a status glyph and the message. It slides in,
/// goes away by itself (held while the pointer is on it), and a click
/// dismisses it. An error is tinted and has a close button.
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
    _timer = Timer(
      widget.toast.isError ? _kErrorShowFor : _kShowFor,
      widget.onDismiss,
    );
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
    final error = widget.toast.isError;
    final radius = BorderRadius.circular(context.radii.pill);
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
            color: error
                ? Color.alphaBlend(c.error.withValues(alpha: 0.12), c.card)
                : c.card,
            elevation: 2,
            shadowColor: c.scrim,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: error ? c.error.withValues(alpha: 0.4) : c.borderStrong,
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
                  error ? s.sm : s.lg,
                  s.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: s.sm,
                  children: [
                    Icon(
                      error
                          ? LucideIcons.circleAlert300
                          : LucideIcons.circleCheck300,
                      size: context.sizes.iconMd,
                      color: error ? c.error : c.success,
                    ),
                    Flexible(
                      child: Text(
                        widget.toast.message,
                        style: context.typography.body.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (error)
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

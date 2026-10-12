import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// The raised card every popup in the app sits on (menus, the emoji and
/// sticker panel): card fill, large radius, hairline border and a soft
/// shadow. Pair it with `appMenuAnchorStyle` so Material draws nothing
/// under it.
class AppPopupCard extends StatelessWidget {
  const AppPopupCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(context.radii.lg);
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: radius,
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.scrim.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

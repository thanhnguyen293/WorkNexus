import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';

/// The app's checkbox mark: a small rounded square, outlined when off and
/// filled with the accent and a tick when on, easing between the two. It only
/// shows the state — the row around it handles the tap and the hover, so
/// there is no Material splash. Not [enabled]: faded.
class AppCheckMark extends StatelessWidget {
  const AppCheckMark({super.key, required this.checked, this.enabled = true});

  final bool checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final side = context.sizes.iconLg;
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.45,
      duration: AppMotion.fast,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: checked ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.xs),
          border: Border.all(color: checked ? c.accent : c.textTertiary),
        ),
        child: AnimatedScale(
          scale: checked ? 1 : 0,
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          child: Icon(
            LucideIcons.check600,
            size: context.sizes.iconSm,
            color: c.onAccent,
          ),
        ),
      ),
    );
  }
}

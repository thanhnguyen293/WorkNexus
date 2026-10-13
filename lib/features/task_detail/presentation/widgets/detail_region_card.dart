import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// One region of the detail body — the description, the activity thread, a
/// metadata group — as its own card on the body's tinted ground, the way
/// ZenTao splits a bug page, so each region reads as a unit at a glance.
class DetailRegionCard extends StatelessWidget {
  const DetailRegionCard({super.key, required this.child, this.padding});

  final Widget child;

  /// Inner padding; the regular region inset when null.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(context.spacing.xl2),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

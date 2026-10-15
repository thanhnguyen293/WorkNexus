import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/badges.dart';

/// A realistic skeleton placeholder for a [TicketCard], mirroring its exact
/// layout: header ID + priority, two title lines, and assignee footer.
/// Eliminates Cumulative Layout Shift (CLS) when real tickets resolve.
class TicketCardSkeleton extends StatelessWidget {
  const TicketCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: context.cardBorder,
      ),
      padding: s.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SkeletonBox(width: 52, height: 16, radius: context.radii.xs),
              const Spacer(),
              SkeletonBox(width: 38, height: 16, radius: context.radii.xs),
            ],
          ),
          SizedBox(height: s.md),
          FractionallySizedBox(
            widthFactor: 0.88,
            alignment: Alignment.centerLeft,
            child: SkeletonBox(height: 14, radius: context.radii.xs),
          ),
          SizedBox(height: s.xs),
          FractionallySizedBox(
            widthFactor: 0.55,
            alignment: Alignment.centerLeft,
            child: SkeletonBox(height: 14, radius: context.radii.xs),
          ),
          SizedBox(height: s.md),
          Row(
            children: [
              SkeletonBox(width: 18, height: 18, radius: context.radii.pill),
              SizedBox(width: s.sm),
              SkeletonBox(width: 72, radius: context.radii.xs),
            ],
          ),
        ],
      ),
    );
  }
}

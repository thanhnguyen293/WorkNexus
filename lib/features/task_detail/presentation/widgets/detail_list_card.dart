import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hover_surface.dart';
import 'detail_region_card.dart';

/// A list of linked items (a task's subtasks, its related bugs) as its own
/// region below the description: [header], then [rows] split by hairlines,
/// then [footer]. Spaces itself from the region above, so a list that shows
/// nothing leaves no gap.
class DetailListCard extends StatelessWidget {
  const DetailListCard({
    super.key,
    required this.header,
    required this.rows,
    this.footer,
  });

  final Widget header;
  final List<Widget> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final c = context.colors;
    // The rows' hover tint is inset from the card edge, so the card pads by a
    // sliver and the header and row text take the rest of the region inset.
    final inset = s.xl2 - s.sm;
    return Padding(
      padding: EdgeInsets.only(top: s.xl),
      child: DetailRegionCard(
        padding: EdgeInsets.fromLTRB(s.sm, s.xl2, s.sm, s.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: header,
            ),
            SizedBox(height: s.sm),
            for (final (i, row) in rows.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: inset,
                  endIndent: inset,
                  color: c.border,
                ),
              row,
            ],
            if (footer case final footer?)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// One tappable row of a [DetailListCard], its content aligned with the
/// card's header.
class DetailListRow extends StatelessWidget {
  const DetailListRow({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return HoverSurface(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: s.xl2 - s.sm, vertical: s.md),
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: child,
    );
  }
}

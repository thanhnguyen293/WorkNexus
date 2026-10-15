import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';

/// The floating card shown under the cursor while dragging a ticket.
///
/// Matches the exact width of cards in a kanban column, with a subtle lift
/// elevation and slight tilt for tactile physical feedback.
class TicketCardDragFeedback extends StatelessWidget {
  const TicketCardDragFeedback({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = context.sizes.boardColumn - context.spacing.sm * 2;
    return Material(
      color: Colors.transparent,
      elevation: 6,
      shadowColor: context.colors.mixT(context.colors.scrim, 0.38),
      borderRadius: BorderRadius.circular(context.radii.card),
      child: SizedBox(
        width: width,
        child: Transform.rotate(angle: -0.01, child: child),
      ),
    );
  }
}

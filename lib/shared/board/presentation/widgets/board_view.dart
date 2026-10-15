import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/repositories/ticket_repository.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/board_model.dart';
import '../providers/board_providers.dart';
import 'board_column_frame.dart';
import 'board_horizontal_scroll.dart';
import 'ticket_card.dart';
import 'ticket_card_drag_feedback.dart';
import 'ticket_card_skeleton.dart';

class BoardView extends ConsumerWidget {
  const BoardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider);
    return BoardHorizontalScroll(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final col in board.columns) ...[
            _Column(column: col),
            SizedBox(width: context.spacing.xl),
          ],
        ],
      ),
    );
  }
}

class _Column extends ConsumerStatefulWidget {
  const _Column({required this.column});
  final BoardColumn column;

  @override
  ConsumerState<_Column> createState() => _ColumnState();
}

class _ColumnState extends ConsumerState<_Column> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final col = widget.column;
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() => _over = true);
        return true;
      },
      onLeave: (_) => setState(() => _over = false),
      onAcceptWithDetails: (d) {
        setState(() => _over = false);
        getIt<TicketRepository>().moveTicket(d.data, col.status);
      },
      builder: (context, _, _) => BoardColumnFrame(
        highlighted: _over,
        dot: StatusDot(col.status),
        label: statusLabel(l, col.status),
        badge: AppCountBadge(col.count),
        itemCount: col.tickets.length,
        itemBuilder: (context, i) {
          final ticket = col.tickets[i];
          // Keyed by ticket, so a re-sort moves elements instead of
          // rebuilding every card in place with another ticket.
          return Draggable<String>(
            key: ValueKey(ticket.id),
            data: ticket.id,
            feedback: TicketCardDragFeedback(child: TicketCard(ticket)),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: TicketCard(ticket),
            ),
            child: TicketCard(ticket),
          );
        },
      ),
    );
  }
}

/// The 6-column shimmer skeleton shown briefly on load / workspace switch.
class BoardSkeleton extends StatelessWidget {
  const BoardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.all(context.spacing.xl2),
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var col = 0; col < 6; col++) ...[
            SizedBox(
              width: context.sizes.boardColumn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 90, height: 16, radius: context.radii.xs),
                  SizedBox(height: context.spacing.lg),
                  for (var i = 0; i < 3; i++) ...[
                    const TicketCardSkeleton(),
                    SizedBox(height: context.spacing.md),
                  ],
                ],
              ),
            ),
            SizedBox(width: context.spacing.xl),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/repositories/ticket_repository.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/board_model.dart';
import '../board_providers.dart';
import 'ticket_card.dart';

class BoardView extends ConsumerWidget {
  const BoardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(context.spacing.xl2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final col in board.columns) ...[
              _Column(column: col),
              SizedBox(width: context.spacing.xl),
            ],
          ],
        ),
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
    final c = context.colors;
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
      builder: (context, _, _) {
        return Container(
          width: 272,
          decoration: BoxDecoration(
            color: _over ? c.selectionFill : c.surface,
            borderRadius: BorderRadius.circular(context.radii.lg),
            border: context.cardBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.spacing.xl,
                  context.spacing.xl,
                  context.spacing.xl,
                  context.spacing.md,
                ),
                child: Row(
                  children: [
                    StatusDot(col.status),
                    SizedBox(width: context.spacing.md),
                    Text(
                      statusLabel(l, col.status),
                      style: context.typography.bodySmStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    SizedBox(width: context.spacing.md),
                    _CountBadge(col.count),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    context.spacing.sm,
                    context.spacing.xxs,
                    context.spacing.sm,
                    context.spacing.md,
                  ),
                  itemCount: col.tickets.length,
                  itemBuilder: (context, i) {
                    final ticket = col.tickets[i];
                    return Draggable<String>(
                      data: ticket.id,
                      feedback: _DragFeedback(child: TicketCard(ticket)),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: TicketCard(ticket),
                      ),
                      child: TicketCard(ticket),
                    );
                  },
                  separatorBuilder: (_, _) =>
                      SizedBox(height: context.spacing.md),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.xl),
        border: context.cardBorder,
      ),
      child: Text(
        '$count',
        style: context.typography.monoSm.copyWith(color: c.textTertiary),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 258,
        child: Transform.rotate(angle: -0.01, child: child),
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
              width: 272,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 90, height: 15, radius: context.radii.xs),
                  SizedBox(height: context.spacing.lg),
                  for (var i = 0; i < 3; i++) ...[
                    SkeletonBox(
                      width: double.infinity,
                      height: 78,
                      radius: context.radii.sm,
                    ),
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

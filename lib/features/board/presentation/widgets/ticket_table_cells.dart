import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/badges.dart';
import 'board_column_frame.dart';
import 'ticket_card_meta.dart';

/// A ticket's ZenTao id, in the mono face ids use across the board.
class TableIdCell extends StatelessWidget {
  const TableIdCell(this.ticket, {super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) => Text(
    ticket.externalKey,
    style: context.typography.mono.copyWith(
      color: context.colors.textSecondary,
    ),
  );
}

/// A ticket's title on one line.
class TableTitleCell extends StatelessWidget {
  const TableTitleCell(this.ticket, {super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) => Text(
    ticket.title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.typography.secondary.copyWith(
      color: context.colors.textPrimary,
    ),
  );
}

/// A board column's status — the same dot and label as its column header.
class TableStatusCell extends StatelessWidget {
  const TableStatusCell(this.label, this.color, {super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      BoardColumnDot(color),
      SizedBox(width: context.spacing.sm),
      Expanded(child: TableTextCell(label)),
    ],
  );
}

/// The ticket's priority tag, when its provider sets one.
class TablePriorityCell extends StatelessWidget {
  const TablePriorityCell(this.ticket, {super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) => hasExplicitPriority(ticket)
      ? _Fit(PriorityTag(ticket.providerType, ticket.priority))
      : const SizedBox.shrink();
}

/// The bug's severity tag, when it has one.
class TableSeverityCell extends StatelessWidget {
  const TableSeverityCell(this.ticket, {super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) => switch (ticket.severity) {
    final severity? => _Fit(SeverityTag(severity)),
    null => const SizedBox.shrink(),
  };
}

/// Who the ticket is assigned to, as on its card.
class TableAssigneeCell extends StatelessWidget {
  const TableAssigneeCell(this.ticket, {super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) => AssigneeChip(
    ticket.assignee,
    context.colors.accent,
    // Chat photos exist for ZenTao people only.
    accountId: ticket.providerType == ProviderType.zentao
        ? ticket.accountId
        : null,
  );
}

/// When the ticket last changed, in the user's date format.
class TableUpdatedCell extends ConsumerWidget {
  const TableUpdatedCell(this.ticket, {super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    formatWhen(
      context,
      ticket.updatedAt,
      format: ref.watch(appSettingsProvider.select((s) => s.dateFormat)),
    ),
    maxLines: 1,
    style: context.typography.monoSm.copyWith(
      color: context.colors.textTertiary,
    ),
  );
}

/// Plain secondary text on one line; empty text shows nothing.
class TableTextCell extends StatelessWidget {
  const TableTextCell(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.typography.meta.copyWith(
      color: context.colors.textSecondary,
    ),
  );
}

/// Shrinks a tag to its cell rather than overflowing a narrow column.
class _Fit extends StatelessWidget {
  const _Fit(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: child,
  );
}

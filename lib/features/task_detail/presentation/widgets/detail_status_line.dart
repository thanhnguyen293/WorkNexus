import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import 'bug_status_strip.dart';

/// The ticket's state under its title: the status pill first, then priority
/// and severity, all one size so the row reads as a single line of tags.
class DetailStatusLine extends StatelessWidget {
  const DetailStatusLine({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Wrap(
      spacing: context.spacing.lg,
      runSpacing: context.spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (ticket.providerEntity case final ZenTaoBugEntity bug)
          BugStatusStrip(ticket: ticket, bug: bug)
        else
          TintedPill(
            color: statusColor(c, ticket.status),
            label: statusLabel(l, ticket.status),
            large: true,
          ),
        if (hasExplicitPriority(ticket))
          PriorityTag(ticket.providerType, ticket.priority, large: true),
        if (ticket.severity != null) SeverityTag(ticket.severity, large: true),
      ],
    );
  }
}

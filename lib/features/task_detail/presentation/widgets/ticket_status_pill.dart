import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import 'bug_status_strip.dart';

/// A ticket's status as a pill, for the Status row of the detail sidebar: a
/// ZenTao bug's own status (with its resolution), anything else's unified
/// status.
class TicketStatusPill extends StatelessWidget {
  const TicketStatusPill({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    if (ticket.providerEntity case final ZenTaoBugEntity bug) {
      return BugStatusStrip(ticket: ticket, bug: bug);
    }
    return TintedPill(
      color: statusColor(context.colors, ticket.status),
      label: statusLabel(AppL10n.of(context), ticket.status),
    );
  }
}

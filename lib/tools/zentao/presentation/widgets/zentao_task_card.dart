import 'package:flutter/widgets.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import 'zentao_ticket_card.dart';

/// A ZenTao task's Kanban card: the bug card's look, tagged with its priority.
class ZenTaoTaskCard extends StatelessWidget {
  const ZenTaoTaskCard(this.ticket, {super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) => ZenTaoTicketCard(
    ticket,
    kind: AppL10n.of(context).cardKindTask,
    badge: PriorityTag(ProviderType.zentao, ticket.priority),
  );
}

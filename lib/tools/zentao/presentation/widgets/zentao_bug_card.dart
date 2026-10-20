import 'package:flutter/widgets.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/widgets/ticket_card_meta.dart';
import 'zentao_ticket_card.dart';

/// A ZenTao bug's Kanban card: tagged with its severity.
class ZenTaoBugCard extends StatelessWidget {
  const ZenTaoBugCard(this.ticket, {super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) => ZenTaoTicketCard(
    ticket,
    kind: AppL10n.of(context).cardKindBug,
    badge: switch (ticket.severity) {
      final severity? => SeverityTag(severity),
      null => null,
    },
  );
}

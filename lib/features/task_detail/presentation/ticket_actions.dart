import 'package:flutter/material.dart';

import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import 'widgets/github_ticket_actions.dart';
import 'widgets/gitlab_ticket_actions.dart';
import 'widgets/zentao_ticket_actions.dart';

/// The action row shown under the detail header, dispatched by provider. Only
/// providers whose write actions are implemented render anything; each provider's
/// bar lives in its own `widgets/<provider>_ticket_actions.dart`.
class TicketActionsBar extends StatelessWidget {
  const TicketActionsBar({super.key, required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return switch (ticket.providerType) {
      ProviderType.zentao => ZenTaoActions(ticket: ticket),
      ProviderType.gitlab => GitLabActions(ticket: ticket),
      ProviderType.github => GitHubActions(ticket: ticket),
      ProviderType.jira => const SizedBox.shrink(),
    };
  }
}

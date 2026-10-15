import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/ticket.dart';
import '../../../core/tools/tool_registry_provider.dart';

/// The action row shown under the detail header, dispatched by provider via ToolModule.
class TicketActionsBar extends ConsumerWidget {
  const TicketActionsBar({super.key, required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(toolRegistryProvider);
    final module = registry[ticket.providerType];
    return module?.buildActions(context, ticket) ?? const SizedBox.shrink();
  }
}

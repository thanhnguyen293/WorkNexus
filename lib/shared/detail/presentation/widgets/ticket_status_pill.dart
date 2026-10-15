import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/tools/tool_registry_provider.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';

/// A ticket's status as a pill, for the Status row of the detail sidebar: a
/// provider-specific status strip (if the tool module supplies one), or the
/// unified status pill fallback.
class TicketStatusPill extends ConsumerWidget {
  const TicketStatusPill({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolRegistryProvider)[ticket.providerType];
    final customStrip = tool?.buildStatusStrip(context, ticket);
    if (customStrip != null) {
      return customStrip;
    }
    return TintedPill(
      color: statusColor(context.colors, ticket.status),
      label: statusLabel(AppL10n.of(context), ticket.status),
    );
  }
}

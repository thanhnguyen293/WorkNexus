import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/tinted_pill.dart';

/// A ZenTao bug's status pill, in the sidebar's Status row: its raw status,
/// with the resolution folded in once resolved ("Resolved · Fixed").
class BugStatusStrip extends StatelessWidget {
  const BugStatusStrip({super.key, required this.ticket, required this.bug});

  final Ticket ticket;
  final ZenTaoBugEntity bug;

  @override
  Widget build(BuildContext context) {
    final raw = ticket.providerStatus.trim();
    if (raw.isEmpty) return const SizedBox.shrink();
    // The resolution is how the bug was resolved, so it reads as part of the
    // status rather than as a chip of its own.
    final resolution = raw.toLowerCase() == 'active'
        ? null
        : zentaoResolutionLabel(bug.resolution);
    return TintedPill(
      color: statusColor(context.colors, ticket.status),
      icon: _statusIcon(raw),
      label: [_capitalize(raw), ?resolution].join(' · '),
    );
  }

  IconData _statusIcon(String raw) => switch (raw.toLowerCase()) {
    'active' => LucideIcons.circleAlert300,
    'resolved' => LucideIcons.checkCircle300,
    'closed' => LucideIcons.xCircle300,
    _ => LucideIcons.circle300,
  };

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

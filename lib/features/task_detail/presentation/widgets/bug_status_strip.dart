import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';

/// The at-a-glance chip row for a ZenTao bug, in the detail header: raw status, confirmation, reopen
/// count — signals that were buried in the flat details table.
class BugStatusStrip extends StatelessWidget {
  const BugStatusStrip({super.key, required this.ticket, required this.bug});

  final Ticket ticket;
  final ZenTaoBugEntity bug;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final raw = ticket.providerStatus.trim();
    final active = raw.toLowerCase() == 'active';
    // The resolution is how the bug was resolved, so it reads as part of the
    // status ("Resolved · Fixed") rather than as a chip of its own.
    final resolution = active ? null : zentaoResolutionLabel(bug.resolution);
    final chips = <Widget>[
      if (raw.isNotEmpty)
        TintedPill(
          color: statusColor(c, ticket.status),
          icon: _statusIcon(raw),
          label: [_capitalize(raw), ?resolution].join(' · '),
          large: true,
        ),
      // Whether an open bug was confirmed matters for triage; once it is
      // resolved or closed the flag is history.
      if (active && bug.confirmed == 1)
        TintedPill(
          color: c.success,
          icon: LucideIcons.badgeCheck300,
          label: l.confirmed,
          large: true,
        ),
      if ((bug.activatedCount ?? 0) > 0)
        TintedPill(
          color: c.warning,
          icon: LucideIcons.rotateCcw300,
          label: l.reopenedTimes(bug.activatedCount ?? 0),
          large: true,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: context.spacing.sm,
      runSpacing: context.spacing.sm,
      children: chips,
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

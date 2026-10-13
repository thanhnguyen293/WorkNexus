import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';

/// The at-a-glance status of a ZenTao bug, in the detail header: its raw
/// status as the one coloured pill, then confirmation and reopen count as
/// quieter inline signals, so the status is what reads first.
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
        _Signal(
          color: c.success,
          icon: LucideIcons.badgeCheck300,
          label: l.confirmed,
        ),
      if ((bug.activatedCount ?? 0) > 0)
        _Signal(
          color: c.warning,
          icon: LucideIcons.rotateCcw300,
          label: l.reopenedTimes(bug.activatedCount ?? 0),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: context.spacing.lg,
      runSpacing: context.spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
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

/// A secondary status signal: an icon and text in [color], with no fill, so
/// it sits beside the status pill without competing with it.
class _Signal extends StatelessWidget {
  const _Signal({required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: context.typography.secondary.fontSize, color: color),
        SizedBox(width: context.spacing.xs),
        Text(label, style: context.typography.secondary.copyWith(color: color)),
      ],
    );
  }
}

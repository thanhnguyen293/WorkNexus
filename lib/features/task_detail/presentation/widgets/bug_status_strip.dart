import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';

/// The at-a-glance chip row for a ZenTao bug: raw status, confirmation, reopen
/// count, and resolution — signals that were buried in the flat details table.
class BugStatusStrip extends StatelessWidget {
  const BugStatusStrip({super.key, required this.ticket, required this.bug});

  final Ticket ticket;
  final ZenTaoBugEntity bug;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final raw = ticket.providerStatus.trim();
    final chips = <Widget>[
      if (raw.isNotEmpty)
        TintedPill(
          color: statusColor(c, ticket.status),
          icon: _statusIcon(raw),
          label: _capitalize(raw),
          pill: true,
        ),
      if (bug.confirmed == 1)
        TintedPill(
          color: c.success,
          icon: Icons.check_circle_outline,
          label: l.confirmed,
          pill: true,
        ),
      if ((bug.activatedCount ?? 0) > 0)
        TintedPill(
          color: c.warning,
          icon: Icons.refresh,
          label: l.reopenedTimes(bug.activatedCount!),
          pill: true,
        ),
      if (zentaoResolutionLabel(bug.resolution) != null)
        TintedPill(
          color: c.info,
          icon: Icons.task_alt,
          label: zentaoResolutionLabel(bug.resolution)!,
          pill: true,
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
    'active' => Icons.error_outline,
    'resolved' => Icons.task_alt,
    'closed' => Icons.check_circle_outline,
    _ => Icons.circle_outlined,
  };

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

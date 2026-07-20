import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../l10n/app_localizations.dart';

/// A colored severity chip (Critical / Major / Minor / Trivial) for a ZenTao
/// bug card. Dot + label tinted by [severityColor].
class SeverityTag extends StatelessWidget {
  const SeverityTag(this.severity, {super.key});
  final int severity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = severityColor(c, severity) ?? c.textTertiary;
    final label = zentaoSeverityLabel(severity) ?? 'S$severity';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(color, 0.15),
        borderRadius: BorderRadius.circular(context.radii.md),
        border: context.borders.showOutline
            ? Border.all(color: c.mixT(color, 0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: context.spacing.xs),
          Text(label, style: context.typography.badge.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// The card's assignee line: a small initial avatar + name (tinted by the
/// ticket's workspace [accent]), or a muted "unassigned" placeholder.
class AssigneeChip extends StatelessWidget {
  const AssigneeChip(this.assignee, this.accent, {super.key});
  final String? assignee;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final name = assignee?.trim() ?? '';

    if (name.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 13, color: c.textTertiary),
          SizedBox(width: context.spacing.xs),
          Text(
            l.unassigned,
            style: context.typography.monoXs.copyWith(color: c.textTertiary),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.mixT(accent, 0.22),
            shape: BoxShape.circle,
          ),
          child: Text(
            name.characters.first.toUpperCase(),
            style: context.typography.badgeSm.copyWith(color: accent),
          ),
        ),
        SizedBox(width: context.spacing.sm),
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: context.typography.bodySm.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

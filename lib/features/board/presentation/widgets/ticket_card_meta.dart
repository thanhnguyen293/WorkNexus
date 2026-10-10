import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/navigation/person_chip.dart';

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
/// Diameter of the assignee avatar on a card.
const double _kAvatar = 18;

class AssigneeChip extends ConsumerWidget {
  const AssigneeChip(this.assignee, this.accent, {super.key, this.accountId});
  final String? assignee;
  final Color accent;

  /// The ZenTao account the ticket came through; when set (and chat is wired
  /// in), the assignee shows their chat photo instead of an initial.
  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final name = assignee?.trim() ?? '';

    if (name.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsLight.userMinus, size: 13, color: c.textTertiary),
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
        switch ((accountId, ref.watch(personAvatarBuilderProvider))) {
          (final id?, final avatar?) => avatar(
            context,
            accountId: id,
            name: name,
            diameter: _kAvatar,
          ),
          _ => Container(
            width: _kAvatar,
            height: _kAvatar,
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
        },
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// A status chip: a colored dot and ZenTao's word for the status.
class MyWorkStatusChip extends StatelessWidget {
  const MyWorkStatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
      decoration: BoxDecoration(
        color: c.mixT(color, 0.12),
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: s.sm,
            height: s.sm,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: s.xs),
          Text(label, style: context.typography.badge.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// A quiet icon + text fact in a row's meta line (sprint, subtasks…).
class MyWorkFact extends StatelessWidget {
  const MyWorkFact({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.maxWidth,
  });

  final IconData icon;
  final String text;

  /// Overrides the muted tone, e.g. red for an overdue deadline.
  final Color? color;

  /// Caps long names (sprints) so the other facts stay on the line.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final color = this.color ?? context.colors.textTertiary;
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.typography.caption.copyWith(color: color),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: s.xl, color: color),
        SizedBox(width: s.xs),
        if (maxWidth case final w?)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: w),
            child: label,
          )
        else
          label,
      ],
    );
  }
}

/// "Due Oct 12", red once the day has passed.
class MyWorkDueFact extends StatelessWidget {
  const MyWorkDueFact(this.due, {super.key});

  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = due.isBefore(DateTime(now.year, now.month, now.day));
    final locale = Localizations.localeOf(context).toString();
    return MyWorkFact(
      icon: LucideIcons.calendar300,
      text: AppL10n.of(
        context,
      ).dashboardDue(DateFormat.MMMd(locale).format(due)),
      color: overdue ? context.colors.error : null,
    );
  }
}

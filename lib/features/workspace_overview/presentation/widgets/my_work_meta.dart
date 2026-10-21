import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

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
        Icon(icon, size: context.sizes.iconXs, color: color),
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
    final localDue = due.toLocal();
    final overdue = localDue.isBefore(DateTime(now.year, now.month, now.day));
    final locale = Localizations.localeOf(context).toString();
    return MyWorkFact(
      icon: LucideIcons.calendar300,
      text: AppL10n.of(
        context,
      ).dashboardDue(DateFormat.MMMd(locale).format(localDue)),
      color: overdue ? context.colors.error : null,
    );
  }
}

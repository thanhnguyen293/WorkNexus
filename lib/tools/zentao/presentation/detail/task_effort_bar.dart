import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/hours_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/summarize_task_effort.dart';

/// A ZenTao task's hours as a progress bar — logged against left, with the
/// estimate under it — opening the task's body, since "how far along is it"
/// is the question a task is opened for. Renders nothing for a task with no
/// hours on record.
class TaskEffortBar extends StatelessWidget {
  const TaskEffortBar({super.key, required this.task});

  final ZenTaoTaskEntity task;

  @override
  Widget build(BuildContext context) {
    final effort = const SummarizeTaskEffort()(task);
    if (effort == null) return const SizedBox.shrink();
    final c = context.colors;
    final l = AppL10n.of(context);
    final t = context.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.zentaoHoursLogged(hoursText(effort.consumed)),
                style: t.bodyStrong.copyWith(color: c.textPrimary),
              ),
            ),
            Text(
              l.taskHoursLeft(hoursText(effort.left)),
              style: t.secondary.copyWith(color: c.textSecondary),
            ),
          ],
        ),
        SizedBox(height: context.spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.pill),
          child: LinearProgressIndicator(
            value: effort.progress,
            minHeight: context.spacing.sm,
            color: c.accent,
            backgroundColor: c.surfaceSubtle,
          ),
        ),
        if (effort.estimate > 0) ...[
          SizedBox(height: context.spacing.sm),
          Text(
            l.taskEstimateHours(hoursText(effort.estimate)),
            style: t.caption.copyWith(color: c.textTertiary),
          ),
        ],
      ],
    );
  }
}

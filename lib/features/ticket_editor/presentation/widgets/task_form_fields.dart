import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'editor_date_input.dart';
import 'editor_inputs.dart';
import 'editor_level_input.dart';

/// Date range input for Start Date and Deadline side-by-side with a dash separator.
class TaskTimeframeInput extends StatelessWidget {
  const TaskTimeframeInput({
    super.key,
    required this.estStarted,
    required this.deadline,
    required this.onEstStartedChanged,
    required this.onDeadlineChanged,
  });

  final String estStarted;
  final String deadline;
  final ValueChanged<String> onEstStartedChanged;
  final ValueChanged<String> onDeadlineChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final c = context.colors;

    return Row(
      children: [
        Expanded(
          child: EditorDateInput(
            value: estStarted,
            onChanged: onEstStartedChanged,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: s.xs),
          child: Text(
            '-',
            style: context.typography.bodyStrong.copyWith(
              color: c.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: EditorDateInput(value: deadline, onChanged: onDeadlineChanged),
        ),
      ],
    );
  }
}

/// Priority selector and Estimate (hours) input in a single compact row.
class TaskPriorityEstimateInput extends StatelessWidget {
  const TaskPriorityEstimateInput({
    super.key,
    required this.priority,
    required this.estimate,
    required this.onPriorityChanged,
    required this.onEstimateChanged,
  });

  final int priority;
  final double estimate;
  final ValueChanged<int> onPriorityChanged;
  final ValueChanged<String> onEstimateChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: EditorLevelInput(
            level: EditorLevel.priority,
            value: priority,
            onChanged: onPriorityChanged,
          ),
        ),
        SizedBox(width: s.md),
        Expanded(
          flex: 2,
          child: EditorTextInput(
            initial: estimate == 0
                ? ''
                : (estimate == estimate.roundToDouble()
                      ? '${estimate.toInt()}'
                      : '$estimate'),
            numeric: true,
            onChanged: onEstimateChanged,
          ),
        ),
      ],
    );
  }
}

/// Radio selector for post-save navigation choice matching ZenTao web format.
class TaskNextActionSelector extends StatelessWidget {
  const TaskNextActionSelector({
    super.key,
    required this.action,
    required this.onChanged,
  });

  final int
  action; // 0 = Go to Task List, 1 = Go to Story List, 2 = Continue Adding Tasks
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final c = context.colors;

    const options = [
      'Go to Task List',
      'Go to Story List',
      'Continue Adding Tasks',
    ];

    return Wrap(
      spacing: s.lg,
      runSpacing: s.xs,
      children: [
        for (var i = 0; i < options.length; i++)
          InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: s.xxs, horizontal: s.xxs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: action == i ? c.accent : c.borderStrong,
                        width: action == i ? 5 : 1.5,
                      ),
                    ),
                  ),
                  SizedBox(width: s.sm),
                  Text(
                    options[i],
                    style: context.typography.bodySm.copyWith(
                      color: action == i ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

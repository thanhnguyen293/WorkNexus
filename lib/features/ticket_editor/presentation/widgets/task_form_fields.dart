import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
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

/// Where saving a new task goes next — ZenTao's "after" choice on its create
/// form, in the app's terms.
enum TaskAfterSave {
  /// The saved task, in the detail panel.
  openTask,

  /// A fresh form for another task in the same execution.
  continueAdding,

  /// Back to the list the editor was opened over.
  backToList,
}

/// Radio choice of [TaskAfterSave].
class TaskNextActionSelector extends StatelessWidget {
  const TaskNextActionSelector({
    super.key,
    required this.action,
    required this.onChanged,
  });

  final TaskAfterSave action;
  final ValueChanged<TaskAfterSave> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final c = context.colors;
    final l = AppL10n.of(context);
    final labels = {
      TaskAfterSave.openTask: l.taskAfterSaveOpen,
      TaskAfterSave.continueAdding: l.taskAfterSaveContinue,
      TaskAfterSave.backToList: l.taskAfterSaveList,
    };

    return Wrap(
      spacing: s.lg,
      runSpacing: s.xs,
      children: [
        for (final MapEntry(key: option, value: label) in labels.entries)
          InkWell(
            onTap: () => onChanged(option),
            mouseCursor: WidgetStateMouseCursor.clickable,
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
                        color: action == option ? c.accent : c.borderStrong,
                        width: action == option ? 5 : 1.5,
                      ),
                    ),
                  ),
                  SizedBox(width: s.sm),
                  Text(
                    label,
                    style: context.typography.bodySm.copyWith(
                      color: action == option ? c.textPrimary : c.textSecondary,
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

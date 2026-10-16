import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_choices.dart';
import '../providers/task_editor_controller.dart';
import 'editor_field.dart';
import 'editor_inputs.dart';
import 'option_select.dart';

/// An existing task's status and hours consumed / left, as ZenTao's edit form
/// has them (a new task has neither yet).
class TaskProgressFields extends ConsumerWidget {
  const TaskProgressFields({
    super.key,
    required this.route,
    required this.draft,
  });

  final TicketEditorRoute route;
  final TaskDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final controller = ref.read(taskEditorProvider(route).notifier);
    double hours(String v) => double.tryParse(v) ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: EditorField(
            label: l.status,
            child: OptionSelect(
              options: withValue(zentaoTaskStatuses, draft.status),
              value: draft.status,
              onChanged: (v) => controller.edit((d) => d.copyWith(status: v)),
            ),
          ),
        ),
        SizedBox(width: s.lg),
        Expanded(
          child: EditorField(
            label: l.fieldConsumed,
            child: EditorTextInput(
              initial: taskHoursText(draft.consumed),
              numeric: true,
              onChanged: (v) =>
                  controller.edit((d) => d.copyWith(consumed: hours(v))),
            ),
          ),
        ),
        SizedBox(width: s.lg),
        Expanded(
          child: EditorField(
            label: l.fieldLeft,
            child: EditorTextInput(
              initial: taskHoursText(draft.left),
              numeric: true,
              onChanged: (v) =>
                  controller.edit((d) => d.copyWith(left: hours(v))),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hours as the inputs show them: blank for none, no `.0` on whole hours.
String taskHoursText(double h) =>
    h == 0 ? '' : (h == h.roundToDouble() ? '${h.toInt()}' : '$h');

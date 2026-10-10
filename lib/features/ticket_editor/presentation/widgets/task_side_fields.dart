import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import '../../domain/value_objects/zentao_choices.dart';
import '../providers/task_editor_controller.dart';
import '../providers/ticket_editor_state.dart';
import 'editor_date_input.dart';
import 'editor_field.dart';
import 'editor_inputs.dart';
import 'editor_level_input.dart';
import 'editor_section.dart';
import 'option_multi_select.dart';
import 'option_select.dart';
import 'title_color_input.dart';

/// The task's fields, as ZenTao's web form has them; hours left / consumed and
/// the status only once the task exists.
class TaskSideFields extends ConsumerWidget {
  const TaskSideFields({super.key, required this.route, required this.state});

  final TicketEditorRoute route;
  final TaskEditorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final controller = ref.read(taskEditorProvider(route).notifier);
    final draft = state.draft;
    final options = state.form.options;
    final editing = draft.id != null;
    double hours(String v) => double.tryParse(v) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorSection(
          title: l.editorSectionLocation,
          icon: LucideIcons.folders300,
          children: [
            EditorField(
              label: l.fieldExecution,
              required: true,
              missing: state.missing.contains(DraftField.execution),
              child: OptionSelect(
                options: options.executions,
                value: draft.execution,
                onChanged: controller.changeExecution,
              ),
            ),
            EditorField(
              label: l.fieldModule,
              child: OptionSelect(
                options: options.modules,
                value: draft.module,
                noneValue: '0',
                onChanged: (v) => controller.edit((d) => d.copyWith(module: v)),
              ),
            ),
            EditorField(
              label: l.fieldStory,
              child: OptionSelect(
                options: options.stories,
                value: draft.story,
                noneValue: '0',
                onChanged: (v) => controller.edit((d) => d.copyWith(story: v)),
              ),
            ),
            if (options.parents.isNotEmpty)
              EditorField(
                label: l.parentTask,
                child: OptionSelect(
                  options: [
                    for (final o in options.parents)
                      if (o.value != draft.id) o,
                  ],
                  value: draft.parent,
                  noneValue: '0',
                  onChanged: (v) =>
                      controller.edit((d) => d.copyWith(parent: v)),
                ),
              ),
          ],
        ),
        EditorSection(
          title: l.editorSectionClassification,
          icon: LucideIcons.tag300,
          children: [
            EditorField(
              label: l.fieldTaskType,
              required: true,
              missing: state.missing.contains(DraftField.type),
              child: OptionSelect(
                options: withValue(zentaoTaskTypes, draft.type),
                value: draft.type,
                onChanged: (v) => controller.edit((d) => d.copyWith(type: v)),
              ),
            ),
            if (editing)
              EditorField(
                label: l.status,
                child: OptionSelect(
                  options: withValue(zentaoTaskStatuses, draft.status),
                  value: draft.status,
                  onChanged: (v) =>
                      controller.edit((d) => d.copyWith(status: v)),
                ),
              ),
            EditorField(
              label: l.priority,
              child: EditorLevelInput(
                level: EditorLevel.priority,
                value: draft.pri,
                onChanged: (v) => controller.edit((d) => d.copyWith(pri: v)),
              ),
            ),
          ],
        ),
        EditorSection(
          title: l.editorSectionAssignment,
          icon: LucideIcons.userCircle300,
          children: [
            EditorField(
              label: l.fieldAssignTo,
              child: OptionSelect(
                options: options.users,
                value: draft.assignedTo,
                noneValue: '',
                onChanged: (v) =>
                    controller.edit((d) => d.copyWith(assignedTo: v)),
              ),
            ),
            EditorField(
              label: l.fieldEstimate,
              child: EditorTextInput(
                initial: _hours(draft.estimate),
                numeric: true,
                onChanged: (v) =>
                    controller.edit((d) => d.copyWith(estimate: hours(v))),
              ),
            ),
            if (editing) ...[
              EditorField(
                label: l.fieldConsumed,
                child: EditorTextInput(
                  initial: _hours(draft.consumed),
                  numeric: true,
                  onChanged: (v) =>
                      controller.edit((d) => d.copyWith(consumed: hours(v))),
                ),
              ),
              EditorField(
                label: l.fieldLeft,
                child: EditorTextInput(
                  initial: _hours(draft.left),
                  numeric: true,
                  onChanged: (v) =>
                      controller.edit((d) => d.copyWith(left: hours(v))),
                ),
              ),
            ],
            EditorField(
              label: l.fieldEstStarted,
              child: EditorDateInput(
                value: draft.estStarted,
                onChanged: (v) =>
                    controller.edit((d) => d.copyWith(estStarted: v)),
              ),
            ),
            EditorField(
              label: l.fieldDeadline,
              child: EditorDateInput(
                value: draft.deadline,
                onChanged: (v) =>
                    controller.edit((d) => d.copyWith(deadline: v)),
              ),
            ),
            EditorField(
              label: l.fieldMailto,
              child: OptionMultiSelect(
                title: l.fieldMailto,
                options: options.users,
                values: draft.mailto,
                onChanged: (v) => controller.edit((d) => d.copyWith(mailto: v)),
              ),
            ),
          ],
        ),
        EditorSection(
          title: l.editorSectionMore,
          icon: LucideIcons.circleEllipsis300,
          children: [
            EditorField(
              label: l.fieldKeywords,
              child: EditorTextInput(
                initial: draft.keywords,
                onChanged: (v) =>
                    controller.edit((d) => d.copyWith(keywords: v)),
              ),
            ),
            EditorField(
              label: l.fieldColor,
              child: TitleColorInput(
                value: draft.color,
                onChanged: (v) => controller.edit((d) => d.copyWith(color: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _hours(double h) =>
    h == 0 ? '' : (h == h.roundToDouble() ? '${h.toInt()}' : '$h');

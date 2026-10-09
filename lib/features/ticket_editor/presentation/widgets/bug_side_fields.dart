import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import '../../domain/value_objects/zentao_choices.dart';
import '../providers/bug_editor_controller.dart';
import '../providers/ticket_editor_state.dart';
import 'editor_date_input.dart';
import 'editor_field.dart';
import 'editor_inputs.dart';
import 'editor_level_input.dart';
import 'editor_section.dart';
import 'option_multi_select.dart';
import 'option_select.dart';
import 'title_color_input.dart';

/// The bug's fields, as ZenTao's web form has them: where it belongs, what it
/// affects, how bad it is, and who handles it.
class BugSideFields extends ConsumerWidget {
  const BugSideFields({super.key, required this.route, required this.state});

  final TicketEditorRoute route;
  final BugEditorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final controller = ref.read(bugEditorProvider(route).notifier);
    final draft = state.draft;
    final options = state.form.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorSection(
          title: l.editorSectionLocation,
          icon: PhosphorIconsLight.folders,
          children: [
            EditorField(
              label: l.fieldProduct,
              required: true,
              missing: state.missing.contains(DraftField.product),
              child: OptionSelect(
                options: options.products,
                value: draft.product,
                onChanged: (v) => controller.changeScope(product: v),
              ),
            ),
            if (options.branches.isNotEmpty)
              EditorField(
                label: l.fieldBranch,
                child: OptionSelect(
                  options: options.branches,
                  value: draft.branch,
                  noneValue: '0',
                  onChanged: (v) =>
                      controller.edit((d) => d.copyWith(branch: v)),
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
              label: l.project,
              child: OptionSelect(
                options: options.projects,
                value: draft.project,
                noneValue: '0',
                onChanged: (v) => controller.changeScope(project: v),
              ),
            ),
            EditorField(
              label: l.fieldExecution,
              child: OptionSelect(
                options: options.executions,
                value: draft.execution,
                noneValue: '0',
                onChanged: (v) => controller.changeScope(execution: v),
              ),
            ),
            if (options.plans.isNotEmpty)
              EditorField(
                label: l.fieldPlan,
                child: OptionSelect(
                  options: options.plans,
                  value: draft.plan,
                  noneValue: '0',
                  onChanged: (v) => controller.edit((d) => d.copyWith(plan: v)),
                ),
              ),
            EditorField(
              label: l.fieldAffectedBuilds,
              required: true,
              missing: state.missing.contains(DraftField.openedBuilds),
              child: OptionMultiSelect(
                title: l.fieldAffectedBuilds,
                options: options.builds,
                values: draft.openedBuilds,
                onChanged: (v) =>
                    controller.edit((d) => d.copyWith(openedBuilds: v)),
              ),
            ),
          ],
        ),
        EditorSection(
          title: l.editorSectionClassification,
          icon: PhosphorIconsLight.tag,
          children: [
            EditorField(
              label: l.fieldType,
              child: OptionSelect(
                options: withValue(zentaoBugTypes, draft.type),
                value: draft.type,
                onChanged: (v) => controller.edit((d) => d.copyWith(type: v)),
              ),
            ),
            EditorField(
              label: l.severity,
              child: EditorLevelInput(
                level: EditorLevel.severity,
                value: draft.severity,
                onChanged: (v) =>
                    controller.edit((d) => d.copyWith(severity: v)),
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
            EditorField(
              label: l.fieldOs,
              child: OptionMultiSelect(
                title: l.fieldOs,
                options: zentaoOsList,
                values: draft.os,
                onChanged: (v) => controller.edit((d) => d.copyWith(os: v)),
              ),
            ),
            EditorField(
              label: l.fieldBrowser,
              child: OptionMultiSelect(
                title: l.fieldBrowser,
                options: zentaoBrowserList,
                values: draft.browser,
                onChanged: (v) =>
                    controller.edit((d) => d.copyWith(browser: v)),
              ),
            ),
          ],
        ),
        EditorSection(
          title: l.editorSectionAssignment,
          icon: PhosphorIconsLight.userCircle,
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
              label: l.fieldDeadline,
              child: EditorDateInput(
                value: draft.deadline,
                onChanged: (v) =>
                    controller.edit((d) => d.copyWith(deadline: v)),
              ),
            ),
          ],
        ),
        EditorSection(
          title: l.editorSectionMore,
          icon: PhosphorIconsLight.dotsThreeCircle,
          children: [
            EditorField(
              label: l.fieldStory,
              child: OptionSelect(
                options: options.stories,
                value: draft.story,
                noneValue: '0',
                onChanged: (v) => controller.edit((d) => d.copyWith(story: v)),
              ),
            ),
            EditorField(
              label: l.fieldTask,
              child: OptionSelect(
                options: options.tasks,
                value: draft.task,
                noneValue: '0',
                onChanged: (v) => controller.edit((d) => d.copyWith(task: v)),
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

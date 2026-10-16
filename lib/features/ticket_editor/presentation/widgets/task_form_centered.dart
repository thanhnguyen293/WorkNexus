import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../core/widgets/rich_text_editor.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import '../../domain/value_objects/zentao_choices.dart';
import '../providers/task_editor_controller.dart';
import '../providers/ticket_editor_state.dart';
import 'editor_field.dart';
import 'editor_inputs.dart';
import 'option_select.dart';
import 'task_form_fields.dart';
import 'task_form_mode_toggle.dart';
import 'task_optional_fields.dart';
import 'task_progress_fields.dart';

/// Centered 2-column balanced form layout for creating and editing tasks.
class TaskFormCentered extends ConsumerStatefulWidget {
  const TaskFormCentered({
    super.key,
    required this.route,
    required this.state,
    required this.desc,
    required this.onSave,
    required this.next,
    required this.onNextChanged,
    required this.onClose,
    this.saving = false,
  });

  final TicketEditorRoute route;
  final TaskEditorState state;
  final HtmlEditingController desc;

  final VoidCallback onSave;

  /// Where saving a new task goes next; the editor keeps the choice, so the
  /// header's Save and the shortcut follow it too.
  final TaskAfterSave next;
  final ValueChanged<TaskAfterSave> onNextChanged;
  final VoidCallback onClose;
  final bool saving;

  @override
  ConsumerState<TaskFormCentered> createState() => _TaskFormCenteredState();
}

class _TaskFormCenteredState extends ConsumerState<TaskFormCentered> {
  /// Simple mode: only what a task needs, as ZenTao's simple form; the
  /// optional fields keep their values and are still saved.
  bool _simple = false;

  double _parseHours(String v) => double.tryParse(v) ?? 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final controller = ref.read(taskEditorProvider(widget.route).notifier);
    final draft = widget.state.draft;
    final options = widget.state.form.options;
    final missing = widget.state.missing;
    final isEditing = draft.id != null;
    final l = AppL10n.of(context);
    final full = !_simple;

    final title = switch (draft.id) {
      final id? => l.editTaskTitle(id),
      null => l.newTask,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(context.radii.md),
              border: Border.all(color: c.border),
            ),
            padding: EdgeInsets.all(s.xl2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: context.typography.title.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    TaskFormModeToggle(
                      isLite: _simple,
                      onToggle: (simple) => setState(() => _simple = simple),
                    ),
                  ],
                ),
                SizedBox(height: s.md),
                Divider(color: c.border, height: 1),
                SizedBox(height: s.xl),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EditorField(
                        label: l.fieldExecution,
                        required: true,
                        missing: missing.contains(DraftField.execution),
                        child: OptionSelect(
                          options: options.executions,
                          value: draft.execution,
                          onChanged: controller.changeExecution,
                        ),
                      ),
                    ),
                    SizedBox(width: s.lg),
                    Expanded(
                      child: EditorField(
                        label: l.fieldTaskType,
                        required: true,
                        missing: missing.contains(DraftField.type),
                        child: OptionSelect(
                          options: withValue(zentaoTaskTypes, draft.type),
                          value: draft.type,
                          onChanged: (v) =>
                              controller.edit((d) => d.copyWith(type: v)),
                        ),
                      ),
                    ),
                  ],
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (full) ...[
                      Expanded(
                        child: EditorField(
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
                      ),
                      SizedBox(width: s.lg),
                    ],
                    Expanded(
                      child: EditorField(
                        label: l.fieldAssignTo,
                        child: OptionSelect(
                          options: options.users,
                          value: draft.assignedTo,
                          noneValue: '',
                          onChanged: (v) =>
                              controller.edit((d) => d.copyWith(assignedTo: v)),
                        ),
                      ),
                    ),
                  ],
                ),

                EditorField(
                  label: l.fieldName,
                  required: true,
                  missing: missing.contains(DraftField.name),
                  child: EditorTextInput(
                    initial: draft.name,
                    big: true,
                    onChanged: (v) =>
                        controller.edit((d) => d.copyWith(name: v)),
                  ),
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EditorField(
                        label: '${l.fieldEstStarted} – ${l.fieldDeadline}',
                        child: TaskTimeframeInput(
                          estStarted: draft.estStarted,
                          deadline: draft.deadline,
                          onEstStartedChanged: (v) =>
                              controller.edit((d) => d.copyWith(estStarted: v)),
                          onDeadlineChanged: (v) =>
                              controller.edit((d) => d.copyWith(deadline: v)),
                        ),
                      ),
                    ),
                    SizedBox(width: s.lg),
                    Expanded(
                      child: EditorField(
                        label: '${l.priority} · ${l.fieldEstimate}',
                        child: TaskPriorityEstimateInput(
                          priority: draft.pri,
                          estimate: draft.estimate,
                          onPriorityChanged: (v) =>
                              controller.edit((d) => d.copyWith(pri: v)),
                          onEstimateChanged: (v) => controller.edit(
                            (d) => d.copyWith(estimate: _parseHours(v)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // An existing task's status and hours (ZenTao's edit form).
                if (isEditing)
                  TaskProgressFields(route: widget.route, draft: draft),

                EditorField(
                  label: l.description,
                  child: RichTextEditor(
                    controller: widget.desc,
                    minHeight: 200,
                    imageLoader: (url) => ref
                        .read(zenTaoTicketEditorProvider)
                        .loadImage(widget.route.accountId, url),
                    onUploadImage: controller.uploadImage,
                    onDropFiles: (files) => controller.edit(
                      (d) => d.copyWith(
                        newFiles: [
                          ...d.newFiles,
                          for (final f in files)
                            DraftFile(name: f.name, bytes: f.bytes),
                        ],
                      ),
                    ),
                  ),
                ),

                // Row 6: where saving a new task goes next
                if (!isEditing)
                  EditorField(
                    label: l.taskFormNext,
                    child: TaskNextActionSelector(
                      action: widget.next,
                      onChanged: widget.onNextChanged,
                    ),
                  ),

                // Optional fields, which simple mode leaves out (their values
                // stay, and are saved).
                if (full)
                  TaskOptionalFields(route: widget.route, state: widget.state),
                SizedBox(height: s.xl),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppButton.filled(
                      onPressed: widget.saving ? null : widget.onSave,
                      child: widget.saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l.save),
                    ),
                    SizedBox(width: s.md),
                    AppButton.textNeutral(
                      onPressed: widget.onClose,
                      child: Text(l.back),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

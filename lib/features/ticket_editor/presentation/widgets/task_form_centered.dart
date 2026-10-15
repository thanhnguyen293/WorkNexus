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
import '../../../../core/widgets/attachments_input.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../core/widgets/rich_text_editor.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import '../../domain/value_objects/zentao_choices.dart';
import '../providers/task_editor_controller.dart';
import '../providers/ticket_editor_state.dart';
import 'editor_field.dart';
import 'editor_inputs.dart';
import 'option_multi_select.dart';
import 'option_select.dart';
import 'task_form_fields.dart';
import 'task_form_mode_toggle.dart';

/// Centered 2-column balanced form layout for creating and editing tasks.
class TaskFormCentered extends ConsumerStatefulWidget {
  const TaskFormCentered({
    super.key,
    required this.route,
    required this.state,
    required this.desc,
    required this.onSave,
    required this.onClose,
    this.saving = false,
  });

  final TicketEditorRoute route;
  final TaskEditorState state;
  final HtmlEditingController desc;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final bool saving;

  @override
  ConsumerState<TaskFormCentered> createState() => _TaskFormCenteredState();
}

class _TaskFormCenteredState extends ConsumerState<TaskFormCentered> {
  int _nextAction = 0;
  bool _isLiteMode = false;

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

    final title = isEditing ? 'Edit Task #${draft.id}' : 'Create Task';

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
                // Top Title & Mode Bar
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
                      isLite: _isLiteMode,
                      onToggle: (lite) => setState(() => _isLiteMode = lite),
                    ),
                  ],
                ),
                SizedBox(height: s.md),
                Divider(color: c.border, height: 1),
                SizedBox(height: s.xl),

                // Row 1: Execution & Type
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EditorField(
                        label: 'Execution',
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
                        label: 'Type',
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

                // Row 2: Parent Task & AssignTo
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EditorField(
                        label: 'Parent Task',
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
                    Expanded(
                      child: EditorField(
                        label: 'AssignTo',
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

                // Row 3: Name (Full width)
                EditorField(
                  label: 'Name',
                  required: true,
                  missing: missing.contains(DraftField.name),
                  child: EditorTextInput(
                    initial: draft.name,
                    big: true,
                    onChanged: (v) =>
                        controller.edit((d) => d.copyWith(name: v)),
                  ),
                ),

                // Row 4: Timeframe & Priority + Estimate
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EditorField(
                        label: 'Timeframe',
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
                        label: 'Priority & Est(Unit: h)',
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

                // Row 5: Description (Full width)
                EditorField(
                  label: 'Description',
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

                // Row 6: Next Action Radios
                EditorField(
                  label: 'Next',
                  child: TaskNextActionSelector(
                    action: _nextAction,
                    onChanged: (val) => setState(() => _nextAction = val),
                  ),
                ),

                // Row 7: Module & Story
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EditorField(
                        label: 'Module',
                        child: OptionSelect(
                          options: options.modules,
                          value: draft.module,
                          noneValue: '0',
                          onChanged: (v) =>
                              controller.edit((d) => d.copyWith(module: v)),
                        ),
                      ),
                    ),
                    SizedBox(width: s.lg),
                    Expanded(
                      child: EditorField(
                        label: 'Story',
                        child: OptionSelect(
                          options: options.stories,
                          value: draft.story,
                          noneValue: '0',
                          onChanged: (v) =>
                              controller.edit((d) => d.copyWith(story: v)),
                        ),
                      ),
                    ),
                  ],
                ),

                // Row 8: Attachments
                EditorField(
                  label: 'Files',
                  child: AttachmentsInput(
                    files: draft.files,
                    newFiles: draft.newFiles,
                    onFilesChanged: (v) =>
                        controller.edit((d) => d.copyWith(files: v)),
                    onNewFilesChanged: (v) =>
                        controller.edit((d) => d.copyWith(newFiles: v)),
                  ),
                ),

                // Row 9: Mailto & Tags
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EditorField(
                        label: 'Mailto',
                        child: OptionMultiSelect(
                          title: 'Mailto',
                          options: options.users,
                          values: draft.mailto,
                          onChanged: (v) =>
                              controller.edit((d) => d.copyWith(mailto: v)),
                        ),
                      ),
                    ),
                    SizedBox(width: s.lg),
                    Expanded(
                      child: EditorField(
                        label: 'Tags / Keywords',
                        child: EditorTextInput(
                          initial: draft.keywords,
                          onChanged: (v) =>
                              controller.edit((d) => d.copyWith(keywords: v)),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: s.xl),

                // Centered Save & Back Buttons
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
                          : const Text('Save'),
                    ),
                    SizedBox(width: s.md),
                    AppButton.textNeutral(
                      onPressed: widget.onClose,
                      child: const Text('Back'),
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

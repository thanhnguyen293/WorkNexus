import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/attachments_input.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/task_editor_controller.dart';
import '../providers/ticket_editor_state.dart';
import 'editor_field.dart';
import 'editor_inputs.dart';
import 'option_multi_select.dart';
import 'option_select.dart';
import 'title_color_input.dart';

/// The task fields beyond what a task needs — module, story, files, who to
/// notify, keywords and colour — which the form's simple mode leaves out.
class TaskOptionalFields extends ConsumerWidget {
  const TaskOptionalFields({
    super.key,
    required this.route,
    required this.state,
  });

  final TicketEditorRoute route;
  final TaskEditorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final controller = ref.read(taskEditorProvider(route).notifier);
    final draft = state.draft;
    final options = state.form.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 7: Module & Story
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EditorField(
                label: l.fieldModule,
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
                label: l.fieldStory,
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
          label: l.attachments,
          child: AttachmentsInput(
            files: draft.files,
            newFiles: draft.newFiles,
            onFilesChanged: (v) => controller.edit((d) => d.copyWith(files: v)),
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
                label: l.fieldMailto,
                child: OptionMultiSelect(
                  title: l.fieldMailto,
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
                label: l.fieldKeywords,
                child: EditorTextInput(
                  initial: draft.keywords,
                  onChanged: (v) =>
                      controller.edit((d) => d.copyWith(keywords: v)),
                ),
              ),
            ),
          ],
        ),
        EditorField(
          label: l.fieldColor,
          child: TitleColorInput(
            value: draft.color,
            onChanged: (v) => controller.edit((d) => d.copyWith(color: v)),
          ),
        ),
      ],
    );
  }
}

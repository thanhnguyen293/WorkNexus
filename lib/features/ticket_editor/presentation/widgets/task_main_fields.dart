import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../core/widgets/rich_text_editor.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import '../providers/task_editor_controller.dart';
import '../providers/ticket_editor_state.dart';
import 'attachments_input.dart';
import 'editor_field.dart';
import 'editor_inputs.dart';
import 'editor_section.dart';

/// The task's text: name, description (rich text) and files.
class TaskMainFields extends ConsumerWidget {
  const TaskMainFields({
    super.key,
    required this.route,
    required this.state,
    required this.desc,
  });

  final TicketEditorRoute route;
  final TaskEditorState state;

  /// The description as edited (read back into the draft on save).
  final HtmlEditingController desc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final controller = ref.read(taskEditorProvider(route).notifier);
    final draft = state.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorSection(
          title: l.editorSectionContent,
          icon: LucideIcons.textAlignStart300,
          children: [
            EditorField(
              label: l.fieldName,
              required: true,
              missing: state.missing.contains(DraftField.name),
              child: EditorTextInput(
                initial: draft.name,
                big: true,
                onChanged: (v) => controller.edit((d) => d.copyWith(name: v)),
              ),
            ),
            EditorField(
              label: l.description,
              child: RichTextEditor(
                controller: desc,
                minHeight: 240,
                imageLoader: (url) => ref
                    .read(zenTaoTicketEditorProvider)
                    .loadImage(route.accountId, url),
                onUploadImage: controller.uploadImage,
                // Other dropped files join the attachments.
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
          ],
        ),
        EditorSection(
          title: l.attachments,
          icon: LucideIcons.paperclip300,
          children: [
            AttachmentsInput(
              files: draft.files,
              newFiles: draft.newFiles,
              onFilesChanged: (v) =>
                  controller.edit((d) => d.copyWith(files: v)),
              onNewFilesChanged: (v) =>
                  controller.edit((d) => d.copyWith(newFiles: v)),
            ),
            SizedBox(height: context.spacing.xl),
          ],
        ),
      ],
    );
  }
}

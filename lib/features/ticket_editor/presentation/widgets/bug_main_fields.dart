import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../core/widgets/rich_text_editor.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import '../providers/bug_editor_controller.dart';
import '../providers/ticket_editor_state.dart';
import 'attachments_input.dart';
import 'editor_field.dart';
import 'editor_inputs.dart';
import 'editor_section.dart';

/// The bug's text: title, repro steps (rich text) and files.
class BugMainFields extends ConsumerWidget {
  const BugMainFields({
    super.key,
    required this.route,
    required this.state,
    required this.steps,
  });

  final TicketEditorRoute route;
  final BugEditorState state;

  /// The steps as edited (read back into the draft on save).
  final HtmlEditingController steps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final controller = ref.read(bugEditorProvider(route).notifier);
    final draft = state.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorSection(
          title: l.editorSectionContent,
          icon: PhosphorIconsLight.textAlignLeft,
          children: [
            EditorField(
              label: l.fieldTitle,
              required: true,
              missing: state.missing.contains(DraftField.title),
              child: EditorTextInput(
                initial: draft.title,
                big: true,
                onChanged: (v) => controller.edit((d) => d.copyWith(title: v)),
              ),
            ),
            EditorField(
              label: l.fieldSteps,
              child: RichTextEditor(
                controller: steps,
                minHeight: 320,
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
          icon: PhosphorIconsLight.paperclip,
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

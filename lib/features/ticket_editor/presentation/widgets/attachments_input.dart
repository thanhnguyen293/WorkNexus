import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'editor_chip.dart';

/// The files on the bug or task — those already there ([files], removable) and
/// those to add when it is saved ([newFiles]).
class AttachmentsInput extends StatelessWidget {
  const AttachmentsInput({
    super.key,
    required this.files,
    required this.newFiles,
    required this.onFilesChanged,
    required this.onNewFilesChanged,
  });

  final List<TicketAttachment> files;
  final List<DraftFile> newFiles;
  final ValueChanged<List<TicketAttachment>> onFilesChanged;
  final ValueChanged<List<DraftFile>> onNewFilesChanged;

  Future<void> _add() async {
    final picked = await openFiles();
    if (picked.isEmpty) return;
    onNewFilesChanged([
      ...newFiles,
      for (final f in picked)
        DraftFile(name: f.name, bytes: await f.readAsBytes()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Wrap(
      spacing: s.sm,
      runSpacing: s.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final f in files)
          EditorChip(
            icon: LucideIcons.paperclip300,
            label: f.title,
            maxWidth: s.xl6 * 7,
            onRemove: () => onFilesChanged([
              for (final x in files)
                if (x != f) x,
            ]),
          ),
        for (final f in newFiles)
          EditorChip(
            icon: LucideIcons.upload300,
            label: f.name,
            maxWidth: s.xl6 * 7,
            onRemove: () => onNewFilesChanged([
              for (final x in newFiles)
                if (x != f) x,
            ]),
          ),
        AppButton.text(
          size: AppButtonSize.extraSmall,
          onPressed: _add,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: s.xs,
            children: [
              Icon(LucideIcons.plus300, size: s.xl2),
              Text(AppL10n.of(context).addFiles),
            ],
          ),
        ),
      ],
    );
  }
}

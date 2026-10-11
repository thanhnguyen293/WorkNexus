import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_attachments.dart';
import 'chat_labels.dart';

/// Size of an image thumbnail in the preview list.
const double _kThumb = 56;

/// Lets the user review pasted/picked files before sending: images show a
/// thumbnail, others their name and size; any can be removed. Returns the
/// files to send, or null when cancelled.
class AttachmentPreviewDialog extends StatefulWidget {
  const AttachmentPreviewDialog({super.key, required this.files});

  final List<ChatAttachment> files;

  static Future<List<ChatAttachment>?> show(
    BuildContext context,
    List<ChatAttachment> files,
  ) => showDialog<List<ChatAttachment>>(
    context: context,
    builder: (_) => AttachmentPreviewDialog(files: files),
  );

  @override
  State<AttachmentPreviewDialog> createState() =>
      _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends State<AttachmentPreviewDialog> {
  late final List<ChatAttachment> _files = [...widget.files];

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    void send() => Navigator.of(context).pop(_files);
    // Enter sends, so paste → Enter works without reaching for the mouse.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (_files.isNotEmpty) send();
        },
      },
      child: Focus(
        autofocus: true,
        child: AppDialogFrame(
          title: l.chatSendFilesTitle(_files.length),
          maxWidth: context.sizes.dialogMd,
          actions: [
            const Spacer(),
            AppButton.textNeutral(
              size: AppButtonSize.small,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.cancel),
            ),
            AppButton.filled(
              size: AppButtonSize.small,
              icon: LucideIcons.send300,
              onPressed: _files.isEmpty ? null : send,
              child: Text(l.chatSend),
            ),
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
              itemCount: _files.length,
              separatorBuilder: (_, _) => SizedBox(height: s.md),
              itemBuilder: (context, i) => _PreviewRow(
                file: _files[i],
                onRemove: () => setState(() => _files.removeAt(i)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.file, required this.onRemove});

  final ChatAttachment file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final image = isImageAttachment(file.name);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.md),
          child: Container(
            width: _kThumb,
            height: _kThumb,
            color: c.surfaceSubtle,
            child: image
                ? Image.memory(
                    file.bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(LucideIcons.image300, color: c.textSecondary),
                  )
                : Icon(
                    isVideoName(file.name)
                        ? LucideIcons.film300
                        : LucideIcons.file300,
                    color: c.textSecondary,
                  ),
          ),
        ),
        SizedBox(width: context.spacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.body.copyWith(color: c.textPrimary),
              ),
              Text(
                formatFileSize(file.bytes.length),
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ],
          ),
        ),
        AppIconButton(
          icon: LucideIcons.x300,
          tooltip: AppL10n.of(context).chatRemoveAttachment,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

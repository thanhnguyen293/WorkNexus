import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
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
    final c = context.colors;
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
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radii.lg),
          ),
          title: Text(
            l.chatSendFilesTitle(_files.length),
            style: context.typography.title.copyWith(color: c.textPrimary),
          ),
          content: SizedBox(
            width: 460,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _files.length,
                separatorBuilder: (_, _) =>
                    SizedBox(height: context.spacing.md),
                itemBuilder: (context, i) => _PreviewRow(
                  file: _files[i],
                  onRemove: () => setState(() => _files.removeAt(i)),
                ),
              ),
            ),
          ),
          actions: [
            AppButton.textNeutral(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.cancel),
            ),
            SizedBox(width: context.spacing.md),
            AppButton.filled(
              onPressed: _files.isEmpty ? null : send,
              child: Text(l.chatSend),
            ),
          ],
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
                        Icon(PhosphorIconsLight.image, color: c.textSecondary),
                  )
                : Icon(
                    isVideoName(file.name)
                        ? PhosphorIconsLight.filmStrip
                        : PhosphorIconsLight.file,
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
        IconButton(
          tooltip: AppL10n.of(context).chatRemoveAttachment,
          onPressed: onRemove,
          icon: Icon(
            PhosphorIconsLight.x,
            size: context.spacing.xl3,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }
}

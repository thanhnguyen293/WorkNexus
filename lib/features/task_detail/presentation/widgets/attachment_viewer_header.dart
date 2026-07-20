import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../l10n/app_localizations.dart';
import 'attachment_kinds.dart';

/// The attachment viewer's top bar: type icon, name + size, download, close —
/// styled to match the detail-panel header (hairline divider, bordered controls).
class AttachmentViewerHeader extends StatelessWidget {
  const AttachmentViewerHeader({
    super.key,
    required this.attachment,
    required this.saving,
    required this.onSave,
    required this.onClose,
  });

  final TicketAttachment attachment;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = formatFileSize(attachment.size);
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl2,
        context.spacing.lg,
        context.spacing.lg,
        context.spacing.lg,
      ),
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Row(
        children: [
          Icon(_iconFor(attachment.extension), size: 18, color: c.accent),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                if (size != null)
                  Text(
                    size,
                    style: context.typography.caption.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: context.spacing.md),
          _DownloadButton(saving: saving, onTap: onSave),
          SizedBox(width: context.spacing.sm),
          _CloseButton(onTap: onClose),
        ],
      ),
    );
  }

  IconData _iconFor(String? ext) {
    final e = ext?.toLowerCase() ?? '';
    if (kVideoExts.contains(e)) return Icons.videocam_outlined;
    if (kImageExts.contains(e)) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

/// A subtle bordered "download" button matching the detail-panel header style.
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final tint = c.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Container(
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.sm),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saving)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: tint),
              )
            else
              Icon(Icons.download_outlined, size: 15, color: tint),
            SizedBox(width: context.spacing.sm),
            Text(
              l.download,
              style: context.typography.bodySm.copyWith(color: tint),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bordered square close button, mirroring the detail-panel header control.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: AppL10n.of(context).close,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceSubtle,
            borderRadius: BorderRadius.circular(context.radii.sm),
            border: Border.all(color: c.border),
          ),
          child: Icon(Icons.close, size: 15, color: c.textSecondary),
        ),
      ),
    );
  }
}

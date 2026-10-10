import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import 'attachment_viewer_dialog.dart';
import 'section_label.dart';

/// The attachments section — repro videos, screenshots, and logs that were
/// previously dropped on the floor. A tap opens the in-app viewer.
class BugAttachments extends StatelessWidget {
  const BugAttachments({
    super.key,
    required this.ticket,
    required this.attachments,
  });

  final Ticket ticket;
  final List<TicketAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('${l.attachments} · ${attachments.length}'),
        SizedBox(height: context.spacing.md),
        for (var i = 0; i < attachments.length; i++) ...[
          if (i > 0) SizedBox(height: context.spacing.sm),
          _AttachmentRow(ticket: ticket, attachment: attachments[i]),
        ],
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.ticket, required this.attachment});

  final Ticket ticket;
  final TicketAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final subtitle = [
      if (formatFileSize(attachment.size) != null)
        formatFileSize(attachment.size)!,
      if ((attachment.addedBy ?? '').isNotEmpty) attachment.addedBy!,
    ].join(' · ');

    return HoverSurface(
      onTap: () => showAttachmentViewer(context, ticket, attachment),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.sm,
      ),
      color: c.surfaceSubtle,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: Border.all(color: c.border),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.mixT(c.info, 0.16),
              borderRadius: BorderRadius.circular(context.radii.md),
            ),
            child: Icon(
              _iconFor(attachment.extension),
              size: 16,
              color: c.info,
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.secondary.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: context.spacing.xxs),
                  Text(
                    subtitle,
                    style: context.typography.caption.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: context.spacing.md),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radii.md),
              border: Border.all(color: c.border),
            ),
            child: Icon(
              _isViewable(attachment.extension)
                  ? LucideIcons.eye300
                  : LucideIcons.download300,
              size: 15,
              color: c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  bool _isViewable(String? ext) {
    const viewable = {
      'mp4', 'mov', 'm4v', 'webm', // video
      'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic', // image
    };
    return viewable.contains(ext?.toLowerCase());
  }

  IconData _iconFor(String? ext) {
    const video = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};
    const image = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'};
    final e = ext?.toLowerCase() ?? '';
    if (video.contains(e)) return LucideIcons.video300;
    if (image.contains(e)) return LucideIcons.image300;
    if (e == 'pdf') return LucideIcons.fileText300;
    if (e == 'zip' || e == 'rar' || e == '7z')
      return LucideIcons.fileArchive300;
    return LucideIcons.file300;
  }
}

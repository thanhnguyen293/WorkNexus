import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'attachment_kinds.dart';

/// The attachment viewer's top bar: type icon, name + size, download, close —
/// styled to match the detail-panel header (hairline divider, app controls).
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
          Icon(
            _iconFor(attachment.extension),
            size: context.sizes.iconLg,
            color: c.accent,
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
          AppButton.outlinedNeutral(
            size: AppButtonSize.small,
            icon: LucideIcons.download300,
            isLoading: saving,
            onPressed: onSave,
            child: Text(AppL10n.of(context).download),
          ),
          SizedBox(width: context.spacing.sm),
          AppIconButton(
            icon: LucideIcons.x300,
            tooltip: AppL10n.of(context).close,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String? ext) {
    final e = ext?.toLowerCase() ?? '';
    if (kVideoExts.contains(e)) return LucideIcons.video300;
    if (kImageExts.contains(e)) return LucideIcons.image300;
    return LucideIcons.file300;
  }
}

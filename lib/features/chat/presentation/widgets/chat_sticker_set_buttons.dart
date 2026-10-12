import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_sticker.dart';
import 'chat_sticker_image.dart';

/// A sticker set as the pack bar shows it: its id ('' for the user's own),
/// the name to show when it is not the id, the sticker pictured on its
/// button, if any, and whether it can be removed (an imported set).
typedef ChatStickerPackCover = ({
  String pack,
  String? title,
  ChatSticker? cover,
  bool removable,
});

/// A set being imported in the background, as the pack bar shows it.
typedef ChatStickerImporting = ({String title, int done, int total});

/// One set's button on the pack bar: its cover sticker (a star for the
/// user's own); a right-click on an imported set offers to remove it.
class ChatStickerSetButton extends StatelessWidget {
  const ChatStickerSetButton({
    super.key,
    required this.pack,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  final ChatStickerPackCover pack;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<ChatStickerPackCover> onRemove;

  Future<void> _menu(BuildContext context, Offset at) async {
    final picked = await showAppContextMenu(
      context,
      at: at,
      entries: [
        AppMenuEntry(
          icon: LucideIcons.trash2300,
          label: AppL10n.of(context).stickerPackRemove,
          destructive: true,
        ),
      ],
    );
    if (picked == 0) onRemove(pack);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.md);
    return Padding(
      padding: EdgeInsets.only(right: s.xs),
      child: Tooltip(
        message: pack.pack.isEmpty ? l.chatMyStickers : pack.title ?? pack.pack,
        child: Material(
          color: selected ? context.colors.selectionFill : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            borderRadius: radius,
            onTap: onTap,
            onSecondaryTapUp: pack.removable
                ? (d) => _menu(context, d.globalPosition)
                : null,
            child: SizedBox.square(
              dimension: s.xl6,
              child: Padding(
                padding: EdgeInsets.all(s.xs),
                child: switch (pack.cover) {
                  final cover? => ChatStickerImage(sticker: cover),
                  null => Icon(
                    LucideIcons.star300,
                    color: context.colors.textSecondary,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A set still being imported: a ring filling with its progress, named on
/// hover. Not a button — there is nothing to show until it is in.
class ChatStickerImportingMark extends StatelessWidget {
  const ChatStickerImportingMark({super.key, required this.job});

  final ChatStickerImporting job;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(right: s.xs),
      child: Tooltip(
        message: AppL10n.of(
          context,
        ).stickerImportRunning(job.title, job.done, job.total),
        child: SizedBox.square(
          dimension: s.xl6,
          child: Padding(
            padding: EdgeInsets.all(s.lg),
            child: CircularProgressIndicator(
              strokeWidth: context.spacing.xxs,
              value: job.total == 0 ? null : job.done / job.total,
            ),
          ),
        ),
      ),
    );
  }
}

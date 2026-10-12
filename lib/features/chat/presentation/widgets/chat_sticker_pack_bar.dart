import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
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

/// The row under the sticker grid: one button per set (the user's own
/// first), then importing a Telegram set and "+" to add stickers of the
/// user's own. A right-click on an imported set offers to remove it.
class ChatStickerPackBar extends StatelessWidget {
  const ChatStickerPackBar({
    super.key,
    required this.packs,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.onImport,
    required this.onRemove,
  });

  final List<ChatStickerPackCover> packs;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final VoidCallback onImport;

  /// Removes an imported set (after asking).
  final ValueChanged<ChatStickerPackCover> onRemove;

  Future<void> _menu(
    BuildContext context,
    ChatStickerPackCover pack,
    Offset at,
  ) async {
    final l = AppL10n.of(context);
    final picked = await showAppContextMenu(
      context,
      at: at,
      entries: [
        AppMenuEntry(
          icon: LucideIcons.trash2300,
          label: l.stickerPackRemove,
          destructive: true,
        ),
      ],
    );
    if (picked == 0) onRemove(pack);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    return SizedBox(
      height: s.xl6 + s.md * 2,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.all(s.md),
              children: [
                for (final p in packs)
                  _PackButton(
                    tooltip: p.pack.isEmpty
                        ? l.chatMyStickers
                        : p.title ?? p.pack,
                    selected: p.pack == selected,
                    onTap: () => onSelect(p.pack),
                    onSecondaryTapUp: p.removable
                        ? (d) => _menu(context, p, d.globalPosition)
                        : null,
                    child: switch (p.cover) {
                      final cover? => ChatStickerImage(sticker: cover),
                      null => Icon(
                        LucideIcons.star300,
                        color: context.colors.textSecondary,
                      ),
                    },
                  ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: context.colors.border),
          AppIconButton(
            icon: LucideIcons.packagePlus300,
            tooltip: l.stickerImportTitle,
            onPressed: onImport,
          ),
          AppIconButton(
            icon: LucideIcons.plus300,
            tooltip: l.chatAddSticker,
            onPressed: onAdd,
          ),
          SizedBox(width: s.xs),
        ],
      ),
    );
  }
}

class _PackButton extends StatelessWidget {
  const _PackButton({
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.child,
    this.onSecondaryTapUp,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.md);
    return Padding(
      padding: EdgeInsets.only(right: s.xs),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? context.colors.selectionFill : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            borderRadius: radius,
            onTap: onTap,
            onSecondaryTapUp: onSecondaryTapUp,
            child: SizedBox.square(
              dimension: s.xl6,
              child: Padding(padding: EdgeInsets.all(s.xs), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

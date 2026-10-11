import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_sticker.dart';
import 'chat_sticker_image.dart';

/// A sticker set as the pack bar shows it: its name ('' for the user's own)
/// and the sticker pictured on its button, if any.
typedef ChatStickerPackCover = ({String pack, ChatSticker? cover});

/// The row under the sticker grid: one button per set (the user's own
/// first), then "+" to add stickers of their own.
class ChatStickerPackBar extends StatelessWidget {
  const ChatStickerPackBar({
    super.key,
    required this.packs,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final List<ChatStickerPackCover> packs;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

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
                    tooltip: p.pack.isEmpty ? l.chatMyStickers : p.pack,
                    selected: p.pack == selected,
                    onTap: () => onSelect(p.pack),
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
          IconButton(
            tooltip: l.chatAddSticker,
            onPressed: onAdd,
            icon: Icon(
              LucideIcons.plus300,
              color: context.colors.textSecondary,
            ),
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
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_sticker.dart';
import '../providers/sticker_providers.dart';
import 'chat_attachments.dart';
import 'chat_snack.dart';

const int _kColumns = 3;

/// A sticker set; tap sends. With [editable] (the user's own set) the first
/// tile adds images and a right-click removes a sticker.
class ChatStickerGrid extends ConsumerWidget {
  const ChatStickerGrid({
    super.key,
    required this.stickers,
    required this.onPick,
    this.editable = false,
  });

  final List<ChatSticker> stickers;
  final ValueChanged<ChatSticker> onPick;
  final bool editable;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final files = await pickChatAttachments(imagesOnly: true);
    final controller = ref.read(stickerControllerProvider);
    for (final file in files) {
      final result = await controller.add(file.bytes, file.name);
      if (result case Err(:final failure)) {
        if (context.mounted) showChatFailure(context, failure);
        return;
      }
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    ChatSticker sticker,
    Offset at,
  ) async {
    final l = AppL10n.of(context);
    final remove = await showAppContextMenu(
      context,
      at: at,
      entries: [
        AppMenuEntry(
          icon: LucideIcons.trash300,
          label: l.chatRemoveSticker,
          destructive: true,
        ),
      ],
    );
    if (remove == null) return;
    final result = await ref.read(stickerControllerProvider).remove(sticker);
    if (result case Err(:final failure)) {
      if (context.mounted) showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final add = _Tile(
      tooltip: l.chatAddSticker,
      onTap: () => _add(context, ref),
      child: Icon(LucideIcons.image300, color: context.colors.textSecondary),
    );
    if (editable && stickers.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(s.xl3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(dimension: s.xl6 * 2, child: add),
            SizedBox(height: s.lg),
            Text(
              l.chatNoMyStickers,
              textAlign: TextAlign.center,
              style: context.typography.bodySm.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    final lead = editable ? 1 : 0;
    return GridView.builder(
      padding: EdgeInsets.all(s.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kColumns,
      ),
      itemCount: stickers.length + lead,
      itemBuilder: (context, i) {
        if (i < lead) return add;
        final sticker = stickers[i - lead];
        return GestureDetector(
          onSecondaryTapDown: editable
              ? (d) => _remove(context, ref, sticker, d.globalPosition)
              : null,
          child: _Tile(
            onTap: () => onPick(sticker),
            child: _StickerImage(sticker: sticker),
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.onTap, required this.child, this.tooltip});

  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: EdgeInsets.all(context.spacing.xs),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: BorderRadius.circular(context.radii.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.spacing.sm),
          child: Center(child: child),
        ),
      ),
    );
    final message = tooltip;
    return message == null ? tile : Tooltip(message: message, child: tile);
  }
}

class _StickerImage extends StatelessWidget {
  const _StickerImage({required this.sticker});

  final ChatSticker sticker;

  @override
  Widget build(BuildContext context) {
    // Tiles are small: decode at about their size.
    final width =
        (context.spacing.xl6 * 2 * MediaQuery.devicePixelRatioOf(context))
            .round();
    final broken = Icon(
      LucideIcons.imageOff300,
      color: context.colors.textTertiary,
    );
    return sticker.custom
        ? Image.file(
            File(sticker.location),
            cacheWidth: width,
            errorBuilder: (_, _, _) => broken,
          )
        : Image.asset(
            sticker.location,
            cacheWidth: width,
            errorBuilder: (_, _, _) => broken,
          );
  }
}

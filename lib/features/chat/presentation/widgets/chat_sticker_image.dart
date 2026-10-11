import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_sticker.dart';

/// A sticker's image: a bundled asset or one of the user's files.
class ChatStickerImage extends StatelessWidget {
  const ChatStickerImage({super.key, required this.sticker});

  final ChatSticker sticker;

  @override
  Widget build(BuildContext context) {
    // Shown small: decode at about a grid tile's size.
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

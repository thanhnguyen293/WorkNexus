import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/sticker_providers.dart';
import 'chat_snack.dart';

/// Keeps a chat image as one of the user's stickers and says how it went.
/// True when it was saved.
Future<bool> saveImageAsSticker(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required ImageContent image,
}) async {
  final l = AppL10n.of(context);
  final result = await ref
      .read(stickerControllerProvider)
      .saveImage(accountId, image);
  if (context.mounted) {
    switch (result) {
      case Ok():
        showChatSnack(context, l.chatStickerSaved);
      case Err(:final failure):
        showChatFailure(context, failure);
    }
  }
  return result is Ok;
}

/// Right-click menu of an image in the chat: save it as a sticker.
Future<void> showImageContextMenu(
  BuildContext context,
  WidgetRef ref, {
  required Offset at,
  required String accountId,
  required ImageContent image,
}) async {
  final save = await showMenu<bool>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    items: [
      PopupMenuItem(
        value: true,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.add_reaction_outlined),
          title: Text(AppL10n.of(context).chatSaveSticker),
        ),
      ),
    ],
  );
  if (save != true || !context.mounted) return;
  await saveImageAsSticker(context, ref, accountId: accountId, image: image);
}

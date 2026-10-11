import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_snack.dart';

/// Puts the original of [image] on the clipboard and says so.
Future<void> copyChatImage(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required ImageContent image,
}) async {
  final copied = AppL10n.of(context).chatCopied;
  final bytes = await ref.read(
    chatAttachmentProvider((
      accountId: accountId,
      content: image,
      thumbnail: false,
    )).future,
  );
  if (bytes case Ok(:final value)) {
    await copyImageToClipboard(value);
    if (context.mounted) showChatSnack(context, copied);
  }
}

/// The image viewer's right-click menu at [at] (global): copy (once the
/// original is loaded, [onCopy] set), save as, and open with the default
/// app. Runs the picked action.
Future<void> showChatImageContextMenu(
  BuildContext context, {
  required Offset at,
  required VoidCallback? onCopy,
  required VoidCallback onSave,
  required VoidCallback onOpenExternally,
}) async {
  final l = AppL10n.of(context);
  final actions = [
    if (onCopy != null) (LucideIcons.copy300, l.chatCopyImage, onCopy),
    (LucideIcons.download300, l.chatSaveAs, onSave),
    (LucideIcons.squareArrowOutUpRight300, l.chatOpenWith, onOpenExternally),
  ];
  final picked = await showAppContextMenu(
    context,
    at: at,
    entries: [
      for (final (icon, label, _) in actions)
        AppMenuEntry(icon: icon, label: label),
    ],
  );
  if (picked != null) actions[picked].$3();
}

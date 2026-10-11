import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/widgets/opencode_not_linked_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import '../providers/message_translation_controller.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';
import 'message_hover_actions.dart';
import 'save_sticker_action.dart';

/// The hover actions a message offers: reply, open its thread, copy text, save an image as a
/// sticker, pin/unpin (where allowed) and — for your own recent messages — retract. Called from a
/// bubble's build, so it watches what the pin action depends on.
List<MessageAction> messageActions(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
  void Function(ChatMessage message) onReply, {
  void Function(int messageId)? onOpenThread,
}) {
  final l = AppL10n.of(context);
  final controller = ref.read(chatControllerProvider);
  final serverId = message.serverId;
  final chat = (accountId: message.accountId, chatGid: message.chatGid);
  final canPin =
      serverId != null &&
      !message.deleted &&
      ref.watch(chatCanPinProvider(chat));
  final pinned =
      canPin &&
      ref.watch(chatIsPinnedProvider((chat: chat, serverId: serverId)));
  final storedTranslation = ref
      .watch(
        messageTranslationProvider((
          accountId: message.accountId,
          gid: message.gid,
        )),
      )
      .asData
      ?.value;
  final translated =
      ref
          .watch(messageTranslationControllerProvider)
          .containsKey(message.gid) ||
      (storedTranslation?.visible ?? false);
  final text = switch (message.content) {
    TextContent(:final text) when !message.deleted => text,
    _ => null,
  };
  return [
    if (serverId != null && !message.deleted)
      (
        icon: LucideIcons.quote300,
        tooltip: l.chatReply,
        destructive: false,
        onTap: () => onReply(message),
      ),
    if (onOpenThread != null && serverId != null)
      (
        icon: LucideIcons.messagesSquare300,
        tooltip: l.chatOpenThread,
        destructive: false,
        onTap: () => onOpenThread(serverId),
      ),
    if (text != null)
      (
        icon: LucideIcons.copy300,
        tooltip: l.chatCopy,
        destructive: false,
        onTap: () => Clipboard.setData(
          ClipboardData(
            text: text.replaceAllMapped(chatMentionPattern, (m) => '@${m[1]}'),
          ),
        ),
      ),
    if (text != null)
      (
        icon: translated ? LucideIcons.languages300 : LucideIcons.languages300,
        tooltip: translated ? l.chatShowOriginal : l.chatTranslate,
        destructive: false,
        onTap: () async {
          final notifier = ref.read(
            messageTranslationControllerProvider.notifier,
          );
          if (translated) return notifier.hide(message);
          // "Translating…" shows at once; the key check (a CLI call that
          // takes a moment) runs behind it. A stored translation needs none.
          await notifier.translate(
            message,
            ready: storedTranslation == null
                ? () => ensureOpenCodeLinked(context, ref)
                : null,
          );
        },
      ),
    if (text != null && storedTranslation != null)
      (
        icon: LucideIcons.rotateCw300,
        tooltip: l.chatRetranslate,
        destructive: false,
        onTap: () => ref
            .read(messageTranslationControllerProvider.notifier)
            .translate(
              message,
              force: true,
              ready: () => ensureOpenCodeLinked(context, ref),
            ),
      ),
    if (message.content case final ImageContent image
        when serverId != null && !message.deleted)
      (
        icon: LucideIcons.sticker300,
        tooltip: l.chatSaveSticker,
        destructive: false,
        onTap: () => saveImageAsSticker(
          context,
          ref,
          accountId: message.accountId,
          image: image,
        ),
      ),
    if (canPin)
      (
        icon: pinned ? LucideIcons.pin500 : LucideIcons.pin300,
        tooltip: pinned ? l.chatUnpin : l.chatPin,
        destructive: false,
        onTap: () async {
          final result = await controller.setPinned(message, pinned: !pinned);
          if (result case Err(:final failure)) {
            if (context.mounted) showChatFailure(context, failure);
          }
        },
      ),
    if (controller.canRetract(message))
      (
        icon: LucideIcons.rotateCcw300,
        tooltip: l.chatRetract,
        destructive: true,
        onTap: () async {
          final result = await controller.retract(message);
          if (result case Err(:final failure)) {
            if (context.mounted) showChatFailure(context, failure);
          }
        },
      ),
  ];
}

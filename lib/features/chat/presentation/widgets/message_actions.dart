import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';
import 'message_hover_actions.dart';

/// The hover actions a message offers: reply, copy text, pin/unpin (where
/// allowed) and — for your own recent messages — retract. Called from a
/// bubble's build, so it watches what the pin action depends on.
List<MessageAction> messageActions(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
  void Function(ChatMessage message) onReply,
) {
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
  final text = switch (message.content) {
    TextContent(:final text) when !message.deleted => text,
    _ => null,
  };
  return [
    if (serverId != null && !message.deleted)
      (
        icon: Icons.reply_rounded,
        tooltip: l.chatReply,
        onTap: () => onReply(message),
      ),
    if (text != null)
      (
        icon: Icons.content_copy_rounded,
        tooltip: l.chatCopy,
        onTap: () => Clipboard.setData(
          ClipboardData(
            text: text.replaceAllMapped(chatMentionPattern, (m) => '@${m[1]}'),
          ),
        ),
      ),
    if (canPin)
      (
        icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
        tooltip: pinned ? l.chatUnpin : l.chatPin,
        onTap: () async {
          final result = await controller.setPinned(message, pinned: !pinned);
          if (result case Err(:final failure)) {
            if (context.mounted) showChatFailure(context, failure);
          }
        },
      ),
    if (controller.canRetract(message))
      (
        icon: Icons.undo_rounded,
        tooltip: l.chatRetract,
        onTap: () async {
          final result = await controller.retract(message);
          if (result case Err(:final failure)) {
            if (context.mounted) showChatFailure(context, failure);
          }
        },
      ),
  ];
}

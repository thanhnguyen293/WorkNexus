import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';

/// Right-click menu of a chat in the list: pin it to the top or unpin it.
Future<void> showConversationMenu(
  BuildContext context,
  WidgetRef ref, {
  required ChatConversation chat,
  required Offset at,
}) async {
  final l = AppL10n.of(context);
  final pin = !chat.starred;
  final picked = await showMenu<bool>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    items: [
      PopupMenuItem(
        value: true,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(pin ? Icons.push_pin_outlined : Icons.push_pin_rounded),
          title: Text(pin ? l.chatPinChat : l.chatUnpinChat),
        ),
      ),
    ],
  );
  if (picked != true) return;
  final result = await ref
      .read(chatControllerProvider)
      .setChatStarred(chat, starred: pin);
  if (result case Err(:final failure)) {
    if (context.mounted) showChatFailure(context, failure);
  }
}

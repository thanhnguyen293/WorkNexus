import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';

enum _Action { pin, mute }

/// Right-click menu of a chat in the list: pin/unpin and mute/unmute.
Future<void> showConversationMenu(
  BuildContext context,
  WidgetRef ref, {
  required ChatConversation chat,
  required Offset at,
}) async {
  final l = AppL10n.of(context);
  final pin = !chat.starred;
  final mute = !chat.muted;
  final picked = await showMenu<_Action>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    items: [
      PopupMenuItem(
        value: _Action.pin,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            pin ? PhosphorIconsLight.pushPin : PhosphorIconsFill.pushPin,
          ),
          title: Text(pin ? l.chatPinChat : l.chatUnpinChat),
        ),
      ),
      PopupMenuItem(
        value: _Action.mute,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            mute
                ? PhosphorIconsLight.bellSlash
                : PhosphorIconsLight.bellRinging,
          ),
          title: Text(mute ? l.chatMuteChat : l.chatUnmuteChat),
        ),
      ),
    ],
  );
  if (picked == null) return;
  final controller = ref.read(chatControllerProvider);
  final result = switch (picked) {
    _Action.pin => await controller.setChatStarred(chat, starred: pin),
    _Action.mute => await controller.setChatMuted(chat, muted: mute),
  };
  if (result case Err(:final failure)) {
    if (context.mounted) showChatFailure(context, failure);
  }
}

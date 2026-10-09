import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';

/// Header bell: mutes or unmutes this chat (the same as the chat list's
/// menu). Notifications for every chat are switched in Quick Settings; when
/// the OS blocks them, the bell warns instead.
class ChatMuteToggle extends ConsumerWidget {
  const ChatMuteToggle({super.key, required this.chat});

  final ChatConversation chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final on = ref.watch(
      appSettingsProvider.select((s) => s.chatNotifications),
    );
    final blocked =
        on && ref.watch(chatNotificationPermissionProvider).value == false;
    final muted = chat.muted;
    return IconButton(
      tooltip: blocked
          ? l.chatNotificationsBlockedShort
          : muted
          ? l.chatUnmuteChat
          : l.chatMuteChat,
      onPressed: () async {
        final result = await ref
            .read(chatControllerProvider)
            .setChatMuted(chat, muted: !muted);
        if (result case Err(:final failure)) {
          if (context.mounted) showChatFailure(context, failure);
        }
      },
      icon: Icon(
        blocked
            ? PhosphorIconsLight.bellSimpleRinging
            : muted
            ? PhosphorIconsLight.bellSlash
            : PhosphorIconsLight.bell,
        color: blocked ? c.warning : c.textSecondary,
      ),
    );
  }
}

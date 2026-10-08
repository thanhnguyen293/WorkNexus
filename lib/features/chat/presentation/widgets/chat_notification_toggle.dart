import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Header bell: turns desktop notifications for new messages on and off
/// (remembered in settings).
class ChatNotificationToggle extends ConsumerWidget {
  const ChatNotificationToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      appSettingsProvider.select((s) => s.chatNotifications),
    );
    final l = AppL10n.of(context);
    return IconButton(
      tooltip: on ? l.chatNotificationsOn : l.chatNotificationsOff,
      onPressed: () =>
          ref.read(appSettingsProvider.notifier).setChatNotifications(!on),
      icon: Icon(
        on
            ? Icons.notifications_none_rounded
            : Icons.notifications_off_outlined,
        color: context.colors.textSecondary,
      ),
    );
  }
}

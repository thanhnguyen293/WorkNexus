import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../l10n/app_localizations.dart';

/// A Quick Settings section: whether new chat messages notify, and whether
/// they do even for the chat already open in the focused window.
class ChatNotificationSettings extends ConsumerWidget {
  const ChatNotificationSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final (on, whileViewing) = ref.watch(
      appSettingsProvider.select(
        (s) => (s.chatNotifications, s.chatNotifyWhileViewing),
      ),
    );
    final settings = ref.read(appSettingsProvider.notifier);
    return QuickSettingsSection(
      title: l.notifications,
      children: [
        QuickSettingsSwitchField(
          label: l.chatNotificationsSetting,
          hint: l.chatNotificationsSettingHint,
          value: on,
          onChanged: settings.setChatNotifications,
        ),
        QuickSettingsSwitchField(
          label: l.chatNotifyWhileViewing,
          hint: l.chatNotifyWhileViewingHint,
          value: whileViewing,
          // Means nothing while notifications are off.
          onChanged: on ? settings.setChatNotifyWhileViewing : null,
        ),
      ],
    );
  }
}

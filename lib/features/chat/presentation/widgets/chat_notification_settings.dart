import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Switch(
          value: on,
          onChanged: settings.setChatNotifications,
          title: l.chatNotificationsSetting,
          hint: l.chatNotificationsSettingHint,
        ),
        _Switch(
          value: whileViewing,
          // Means nothing while notifications are off.
          onChanged: on ? settings.setChatNotifyWhileViewing : null,
          title: l.chatNotifyWhileViewing,
          hint: l.chatNotifyWhileViewingHint,
        ),
      ],
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.hint,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: context.typography.bodyStrong.copyWith(
          color: enabled ? c.textPrimary : c.textTertiary,
        ),
      ),
      subtitle: Text(
        hint,
        style: context.typography.caption.copyWith(
          color: enabled ? c.textSecondary : c.textTertiary,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';

/// Header bell: turns desktop notifications for new messages on and off
/// (remembered in settings).
class ChatNotificationToggle extends ConsumerWidget {
  const ChatNotificationToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      appSettingsProvider.select((s) => s.chatNotifications),
    );
    // On in the app but blocked by the OS: warn instead of the plain bell.
    final blocked =
        on && ref.watch(chatNotificationPermissionProvider).value == false;
    final l = AppL10n.of(context);
    return IconButton(
      tooltip: blocked
          ? l.chatNotificationsBlockedShort
          : on
          ? l.chatNotificationsOn
          : l.chatNotificationsOff,
      onPressed: () =>
          ref.read(appSettingsProvider.notifier).setChatNotifications(!on),
      icon: Icon(
        blocked
            ? PhosphorIconsLight.bellSimpleRinging
            : on
            ? PhosphorIconsLight.bell
            : PhosphorIconsLight.bellSlash,
        color: blocked ? context.colors.warning : context.colors.textSecondary,
      ),
    );
  }
}

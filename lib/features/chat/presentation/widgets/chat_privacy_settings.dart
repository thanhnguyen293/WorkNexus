import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_privacy_shortcut.dart';

/// A Quick Settings section: the privacy mode (hiding chats on screen) with
/// the parts it hides, and whether chat peers see when the user is typing.
class ChatPrivacySettings extends ConsumerWidget {
  const ChatPrivacySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final (privacy, typing) = ref.watch(
      appSettingsProvider.select(
        (s) => (s.chatPrivacy, s.chatSendTypingStatus),
      ),
    );
    final settings = ref.read(appSettingsProvider.notifier);
    // The parts mean nothing while the mode is off.
    final on = privacy.enabled;
    return QuickSettingsSection(
      title: l.chatPrivacy,
      children: [
        QuickSettingsSwitchField(
          label: l.chatPrivacyMode,
          hint: l.chatPrivacyModeHint(chatPrivacyShortcutLabel),
          value: on,
          onChanged: (v) =>
              settings.setChatPrivacy(privacy.copyWith(enabled: v)),
        ),
        QuickSettingsSwitchField(
          label: l.chatHidePreviews,
          hint: l.chatHidePreviewsHint,
          value: privacy.hidePreviews,
          onChanged: on
              ? (v) =>
                    settings.setChatPrivacy(privacy.copyWith(hidePreviews: v))
              : null,
        ),
        QuickSettingsSwitchField(
          label: l.chatHideIdentities,
          hint: l.chatHideIdentitiesHint,
          value: privacy.hideIdentities,
          onChanged: on
              ? (v) =>
                    settings.setChatPrivacy(privacy.copyWith(hideIdentities: v))
              : null,
        ),
        QuickSettingsSwitchField(
          label: l.chatHideMessages,
          hint: l.chatHideMessagesHint,
          value: privacy.hideMessages,
          onChanged: on
              ? (v) =>
                    settings.setChatPrivacy(privacy.copyWith(hideMessages: v))
              : null,
        ),
        QuickSettingsSwitchField(
          label: l.chatSendTypingStatus,
          hint: l.chatSendTypingStatusHint,
          value: typing,
          onChanged: settings.setChatSendTypingStatus,
        ),
      ],
    );
  }
}

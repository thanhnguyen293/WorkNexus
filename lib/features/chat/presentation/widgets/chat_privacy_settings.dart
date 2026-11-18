import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_privacy_shortcut.dart';

/// A Quick Settings section: the privacy mode (blurring chats on screen) with
/// the parts it blurs, and whether chat peers see when the user is typing.
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
          label: l.chatBlurPreviews,
          hint: l.chatBlurPreviewsHint,
          value: privacy.blurPreviews,
          onChanged: on
              ? (v) =>
                    settings.setChatPrivacy(privacy.copyWith(blurPreviews: v))
              : null,
        ),
        QuickSettingsSwitchField(
          label: l.chatBlurIdentities,
          hint: l.chatBlurIdentitiesHint,
          value: privacy.blurIdentities,
          onChanged: on
              ? (v) =>
                    settings.setChatPrivacy(privacy.copyWith(blurIdentities: v))
              : null,
        ),
        QuickSettingsSwitchField(
          label: l.chatBlurMessages,
          hint: l.chatBlurMessagesHint,
          value: privacy.blurMessages,
          onChanged: on
              ? (v) =>
                    settings.setChatPrivacy(privacy.copyWith(blurMessages: v))
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../l10n/app_localizations.dart';

/// A Quick Settings section: whether chat peers see when the user is typing.
class ChatPrivacySettings extends ConsumerWidget {
  const ChatPrivacySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final on = ref.watch(
      appSettingsProvider.select((s) => s.chatSendTypingStatus),
    );
    return QuickSettingsSection(
      title: l.chatPrivacy,
      children: [
        QuickSettingsSwitchField(
          label: l.chatSendTypingStatus,
          hint: l.chatSendTypingStatusHint,
          value: on,
          onChanged: ref
              .read(appSettingsProvider.notifier)
              .setChatSendTypingStatus,
        ),
      ],
    );
  }
}

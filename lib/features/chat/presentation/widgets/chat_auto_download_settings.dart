import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../core/widgets/quick_settings_segmented.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_storage_dialog.dart';

/// Sizes offered for the video auto-download limit, in MB.
const List<int> kChatAutoDownloadSizesMb = [10, 20, 50, 100];

/// A Quick Settings section: whether chat videos download on their own, up to
/// what size, and the way into the downloaded-files storage.
class ChatAutoDownloadSettings extends ConsumerWidget {
  const ChatAutoDownloadSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final (on, mb) = ref.watch(
      appSettingsProvider.select(
        (st) => (st.chatAutoDownloadVideos, st.chatAutoDownloadVideoMb),
      ),
    );
    final settings = ref.read(appSettingsProvider.notifier);
    return QuickSettingsSection(
      title: l.quickSettingsDownloads,
      children: [
        QuickSettingsSwitchField(
          label: l.chatAutoDownloadVideos,
          hint: l.chatAutoDownloadVideosHint,
          value: on,
          onChanged: settings.setChatAutoDownloadVideos,
        ),
        if (on)
          QuickSettingsField(
            label: l.chatAutoDownloadUpTo,
            control: QuickSettingsSegmented<int>(
              value: kChatAutoDownloadSizesMb.contains(mb)
                  ? mb
                  : kChatAutoDownloadSizesMb[1],
              options: {
                for (final size in kChatAutoDownloadSizesMb) size: '$size MB',
              },
              onChanged: settings.setChatAutoDownloadVideoMb,
            ),
          ),
        QuickSettingsLinkField(
          icon: LucideIcons.database300,
          label: l.chatStorage,
          onTap: () => ChatStorageDialog.show(context),
        ),
      ],
    );
  }
}

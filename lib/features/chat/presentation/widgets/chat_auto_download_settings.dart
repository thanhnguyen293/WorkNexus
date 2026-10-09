import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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
    final c = context.colors;
    final s = context.spacing;
    final (on, mb) = ref.watch(
      appSettingsProvider.select(
        (st) => (st.chatAutoDownloadVideos, st.chatAutoDownloadVideoMb),
      ),
    );
    final settings = ref.read(appSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: on,
          onChanged: settings.setChatAutoDownloadVideos,
          title: Text(
            l.chatAutoDownloadVideos,
            style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
          ),
          subtitle: Text(
            l.chatAutoDownloadVideosHint,
            style: context.typography.caption.copyWith(color: c.textSecondary),
          ),
        ),
        if (on) ...[
          SizedBox(height: s.sm),
          Row(
            children: [
              Text(
                l.chatAutoDownloadUpTo,
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
              SizedBox(width: s.lg),
              Expanded(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    for (final size in kChatAutoDownloadSizesMb)
                      ButtonSegment(value: size, label: Text('$size MB')),
                  ],
                  selected: {
                    kChatAutoDownloadSizesMb.contains(mb)
                        ? mb
                        : kChatAutoDownloadSizesMb[1],
                  },
                  onSelectionChanged: (picked) =>
                      settings.setChatAutoDownloadVideoMb(picked.first),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: s.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            PhosphorIconsLight.database,
            size: s.xl4,
            color: c.textSecondary,
          ),
          title: Text(
            l.chatStorage,
            style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
          ),
          trailing: Icon(
            PhosphorIconsLight.caretRight,
            size: s.xl3,
            color: c.textTertiary,
          ),
          onTap: () => ChatStorageDialog.show(context),
        ),
      ],
    );
  }
}

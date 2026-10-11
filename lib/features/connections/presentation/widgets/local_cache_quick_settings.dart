import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/open_storage.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../l10n/app_localizations.dart';

/// "Storage & cache" in Quick Settings: the way into the app's storage
/// dialog, as on the Settings page.
class LocalCacheQuickSettings extends ConsumerWidget {
  const LocalCacheQuickSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return QuickSettingsSection(
      title: l.storageTitle,
      children: [
        QuickSettingsLinkField(
          icon: LucideIcons.database300,
          label: l.storageOpen,
          onTap: () => ref.read(openStorageProvider)?.call(context),
        ),
      ],
    );
  }
}

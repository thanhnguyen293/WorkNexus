import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cache_section.dart';
import 'local_cache_card.dart';

/// "Local data" in Quick Settings: the way into clearing the cache, as on
/// the Settings page.
class LocalCacheQuickSettings extends ConsumerWidget {
  const LocalCacheQuickSettings({required this.onCleared, super.key});

  final void Function(Set<CacheSection> sections) onCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return QuickSettingsSection(
      title: l.localCacheTitle,
      children: [
        QuickSettingsLinkField(
          icon: LucideIcons.broom300,
          label: l.clearCache,
          onTap: () => clearLocalCacheFlow(context, ref, onCleared),
        ),
      ],
    );
  }
}

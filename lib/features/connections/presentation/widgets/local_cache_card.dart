import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cache_section.dart';
import '../providers/local_cache_providers.dart';
import 'clear_cache_dialog.dart';

/// Settings' "Local data" card: clears picked parts of the synced cache.
/// [onCleared] gets them back — the app shell resyncs and reconnects, which
/// reaches into features this one must not know.
class LocalCacheCard extends ConsumerWidget {
  const LocalCacheCard({required this.onCleared, super.key});

  final void Function(Set<CacheSection> sections) onCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.localCacheTitle,
          style: context.typography.titleLg.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: s.xs),
        Text(
          l.localCacheSubtitle,
          style: context.typography.paragraph.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: s.xl2),
        Container(
          padding: EdgeInsets.all(s.xl2),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.localCacheHint,
                  style: context.typography.paragraph.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: s.xl),
              AppButton.outlinedNeutral(
                onPressed: () => clearLocalCacheFlow(context, ref, onCleared),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: s.sm,
                  children: [
                    Icon(LucideIcons.broom300, size: s.xl3),
                    Text(l.clearCache),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Asks which parts to clear, clears them, then hands them to [onCleared]
/// and says so; a failure is shown instead. Shared by the Settings card and
/// Quick Settings.
Future<void> clearLocalCacheFlow(
  BuildContext context,
  WidgetRef ref,
  void Function(Set<CacheSection> sections) onCleared,
) async {
  final l = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final sections = await showClearCacheDialog(context);
  if (sections == null) return;
  final result = await ref.read(clearLocalCacheProvider)(sections);
  switch (result) {
    case Ok():
      onCleared(sections);
      messenger.showSnackBar(SnackBar(content: Text(l.cacheCleared)));
    case Err(:final failure):
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

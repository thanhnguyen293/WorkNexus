import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/open_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';

/// Settings' "Storage & cache" card: the way into the app's storage dialog
/// (downloaded chat files and the synced local data).
class LocalCacheCard extends ConsumerWidget {
  const LocalCacheCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.storageTitle,
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
                onPressed: () => ref.read(openStorageProvider)?.call(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: s.sm,
                  children: [
                    Icon(LucideIcons.broom300, size: s.xl3),
                    Text(l.storageOpen),
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

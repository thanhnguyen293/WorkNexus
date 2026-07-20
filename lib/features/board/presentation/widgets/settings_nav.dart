import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// The bottom "Integrations / settings" toggle in the sidebar.
class SettingsNav extends ConsumerWidget {
  const SettingsNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final active = ref.watch(integrationsVisibleProvider);
    return Container(
      decoration: BoxDecoration(border: Border(top: context.hairlineSide)),
      padding: EdgeInsets.all(context.spacing.md),
      child: InkWell(
        onTap: () => ref.read(settingsOpenProvider.notifier).state = !active,
        borderRadius: BorderRadius.circular(context.radii.md),
        child: Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
          decoration: BoxDecoration(
            color: active ? c.selectionFill : Colors.transparent,
            borderRadius: BorderRadius.circular(context.radii.md),
          ),
          child: Row(
            children: [
              Text(
                '⚙',
                style: context.typography.body.copyWith(color: c.textSecondary),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Text(
                  l.integrations,
                  style: context.typography.secondary.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

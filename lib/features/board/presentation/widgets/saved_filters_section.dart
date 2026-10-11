import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/saved_filter.dart';
import '../board_providers.dart';
import '../saved_filter_providers.dart';
import 'save_filter_dialog.dart';

/// The popover's "Saved filters" block: apply a preset with a tap, remove it
/// with its ✕ (after a confirm), or store the filter currently on screen under a name.
class SavedFiltersSection extends ConsumerWidget {
  const SavedFiltersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final presets = ref.watch(savedFiltersProvider);
    final hasFilters = ref.watch(
      filterStateProvider.select((f) => f.hasActiveFilters),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: l.savedFilters),
          SizedBox(height: context.spacing.xs),
          // A read that failed is said out loud, not shown as "no presets yet"
          // (CLAUDE.md 11.3).
          switch (presets) {
            AsyncData(:final value) when value.isEmpty => AppInlineNote(
              text: l.noSavedFiltersYet,
            ),
            AsyncData(:final value) => Wrap(
              spacing: context.spacing.sm,
              runSpacing: context.spacing.sm,
              children: [
                for (final preset in value) _PresetChip(preset: preset),
              ],
            ),
            AsyncError() => AppInlineNote(
              text: l.savedFiltersLoadFailed,
              isError: true,
            ),
            _ => const AppInlineSpinner(),
          },
          SizedBox(height: context.spacing.md),
          // Saving an empty filter would store a preset that does nothing.
          _SaveButton(
            onTap: hasFilters ? () => SaveFilterDialog.show(context) : null,
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends ConsumerWidget {
  const _PresetChip({required this.preset});

  final SavedFilter preset;

  Future<void> _delete(
    BuildContext context,
    SavedFilterController controller,
  ) async {
    final l = AppL10n.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l.boardDeletePresetTitle,
      message: l.boardDeletePresetMessage(preset.name),
      destructive: true,
    );
    if (!confirmed) return;
    final res = await controller.delete(preset.id);
    if (res case Err(:final failure)) {
      if (!context.mounted) return;
      showAppSnack(context, l.actionFailed(failure.message), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final controller = ref.read(savedFilterControllerProvider.notifier);
    return HoverSurface(
      onTap: () => controller.apply(preset),
      height: context.sizes.controlSm,
      padding: EdgeInsets.only(left: context.spacing.lg),
      color: c.surfaceSubtle,
      borderRadius: BorderRadius.circular(context.radii.pill),
      border: context.borders.showOutline ? Border.all(color: c.border) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.meta.copyWith(
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
          ),
          AppIconButton(
            icon: LucideIcons.x300,
            tooltip: l.deleteSavedFilter,
            size: AppIconButtonSize.small,
            onPressed: () => _delete(context, controller),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppButton.outlinedNeutral(
      size: AppButtonSize.small,
      icon: LucideIcons.plus300,
      onPressed: onTap,
      child: Text(AppL10n.of(context).saveCurrentFilter),
    );
  }
}

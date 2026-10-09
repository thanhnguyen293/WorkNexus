import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/saved_filter.dart';
import '../board_providers.dart';
import '../saved_filter_providers.dart';
import 'save_filter_dialog.dart';

/// The popover's "Saved filters" block: apply a preset with a tap, remove it
/// with the ✕, or store the filter currently on screen under a name.
class SavedFiltersSection extends ConsumerWidget {
  const SavedFiltersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
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
          Text(
            l.savedFilters.toUpperCase(),
            style: context.typography.label.copyWith(color: c.textTertiary),
          ),
          SizedBox(height: context.spacing.sm),
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
            _ => AppInlineNote(text: l.noSavedFiltersYet),
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
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppL10n.of(context).actionFailed;
    final res = await controller.delete(preset.id);
    if (res case Err(:final failure)) {
      messenger.showSnackBar(SnackBar(content: Text(failed(failure.message))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final controller = ref.read(savedFilterControllerProvider.notifier);
    // The pill itself has no tap handler — the label and the ✕ inside are the
    // targets — so hover feedback is switched on explicitly.
    return HoverSurface(
      enabled: true,
      height: 26,
      padding: EdgeInsets.only(left: context.spacing.lg),
      color: c.surfaceSubtle,
      borderRadius: BorderRadius.circular(context.radii.pill),
      border: context.borders.showOutline ? Border.all(color: c.border) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Opaque so the whole label — not just the glyphs — applies the
          // preset; same for the ✕, which is a small target to begin with.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.apply(preset),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
              child: Text(
                preset.name,
                style: context.typography.meta.copyWith(
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
          Tooltip(
            message: l.deleteSavedFilter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _delete(context, controller),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.sm,
                  vertical: context.spacing.xs,
                ),
                child: Text(
                  '✕',
                  style: context.typography.meta.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ),
            ),
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
    final c = context.colors;
    final l = AppL10n.of(context);
    final enabled = onTap != null;
    return HoverSurface(
      onTap: onTap,
      height: 26,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
      alignment: Alignment.center,
      color: c.surfaceSubtle,
      borderRadius: BorderRadius.circular(context.radii.pill),
      border: Border.all(color: c.border),
      child: Text(
        '＋ ${l.saveCurrentFilter}',
        style: context.typography.meta.copyWith(
          fontWeight: FontWeight.w500,
          color: enabled ? c.textSecondary : c.textTertiary,
        ),
      ),
    );
  }
}

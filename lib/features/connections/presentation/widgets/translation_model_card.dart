import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../settings_providers.dart';

/// Settings section for the model ticket translation runs on.
///
/// Left unset, OpenCode picks its own default model — which is how a broken or
/// queued default silently turned every translation into a hang. Pinning one
/// here makes that choice explicit and changeable without editing
/// `opencode.json`.
class TranslationModelCard extends ConsumerWidget {
  const TranslationModelCard({super.key});

  /// Sentinel for "no pinned model" — the picker needs a non-null value to show
  /// the default entry as selected.
  static const defaultModel = '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final selected = ref.watch(
      appSettingsProvider.select((s) => s.translationModel),
    );
    final models = ref.watch(openCodeModelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.translationModelSection,
          style: context.typography.titleLg.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: context.spacing.xs),
        Text(
          l.translationModelSubtitle,
          style: context.typography.paragraph.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: context.spacing.xl2),
        Container(
          padding: EdgeInsets.all(context.spacing.xl2),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          child: switch (models) {
            AsyncData(:final value) => _ModelPicker(
              selected: selected,
              models: value,
            ),
            AsyncError() => AppInlineNote(text: l.translationModelLoadFailed),
            _ => const AppInlineSpinner(),
          },
        ),
      ],
    );
  }
}

/// The picker itself: OpenCode's own default plus every model the CLI reports.
/// A pinned model the CLI no longer lists stays in the list so it is visible
/// (and replaceable) rather than silently disappearing.
class _ModelPicker extends ConsumerWidget {
  const _ModelPicker({required this.selected, required this.models});

  final String selected;
  final List<String> models;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final items = <String>[
      TranslationModelCard.defaultModel,
      ...models,
      if (selected.isNotEmpty && !models.contains(selected)) selected,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchableDropdownField<String>(
          items: items,
          value: selected,
          searchHint: l.searchModels,
          emptyLabel: l.noMatches,
          labelOf: (m) => m.isEmpty ? l.translationModelDefault : m,
          onChanged: ref.read(appSettingsProvider.notifier).setTranslationModel,
        ),
        if (models.isEmpty) ...[
          SizedBox(height: context.spacing.md),
          AppInlineNote(text: l.translationModelListUnavailable),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../translation_providers.dart';

/// The model ticket translation runs on through OpenCode.
///
/// Left unset, OpenCode picks its own default model — which is how a broken or
/// queued default silently turned every translation into a hang. Pinning one
/// here makes that choice explicit and changeable without editing
/// `opencode.json`.
class TranslationModelPicker extends ConsumerWidget {
  const TranslationModelPicker({super.key});

  /// Sentinel for "no pinned model" — the picker needs a non-null value to show
  /// the default entry as selected.
  static const defaultModel = '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final selected = ref.watch(
      appSettingsProvider.select((s) => s.translationModel),
    );
    final models = ref.watch(openCodeModelsProvider);

    return switch (models) {
      AsyncData(:final value) => _ModelPicker(
        selected: selected,
        models: value,
      ),
      AsyncError() => AppInlineNote(text: l.translationModelLoadFailed),
      _ => const AppInlineSpinner(),
    };
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
      TranslationModelPicker.defaultModel,
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

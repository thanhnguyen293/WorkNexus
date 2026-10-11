import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/connection_text_field.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../translation_api_providers.dart';

/// The model to translate with: a dropdown of what the endpoint serves, or a
/// text field while the list is loading, cannot be fetched yet (no key), or
/// failed — so a provider without a usable listing never blocks saving.
class TranslationApiModelField extends ConsumerWidget {
  const TranslationApiModelField({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.needsKey,
    required this.controller,
    required this.onChanged,
  });

  final String baseUrl;
  final String apiKey;
  final bool needsKey;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final textField = ConnectionTextField(
      label: l.translationApiModel,
      controller: controller,
      onChanged: onChanged,
    );
    final url = baseUrl.trim();
    final key = apiKey.trim();
    if (url.isEmpty || (needsKey && key.isEmpty)) return textField;

    return switch (ref.watch(
      translationApiModelsProvider((baseUrl: url, apiKey: key)),
    )) {
      AsyncData(value: Ok(:final value)) when value.isNotEmpty =>
        _ModelDropdown(
          models: value,
          selected: controller.text.trim(),
          onChanged: (model) {
            controller.text = model;
            onChanged(model);
          },
        ),
      AsyncData() || AsyncError() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          textField,
          SizedBox(height: context.spacing.xs),
          AppInlineNote(text: l.translationApiModelsLoadFailed),
        ],
      ),
      _ => textField,
    };
  }
}

/// The served models; a saved model the endpoint no longer lists stays in the
/// list so it is visible (and replaceable) rather than silently swapped out.
class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.models,
    required this.selected,
    required this.onChanged,
  });

  final List<String> models;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final items = [
      if (selected.isNotEmpty && !models.contains(selected)) selected,
      ...models,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.translationApiModel,
          style: context.typography.captionStrong.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        SearchableDropdownField<String>(
          items: items,
          value: selected.isEmpty ? null : selected,
          searchHint: l.searchModels,
          emptyLabel: l.noMatches,
          labelOf: (m) => m,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

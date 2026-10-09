import 'package:flutter/material.dart';

import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';

/// A searchable pick of one of [options]; with [noneValue] set, "None" is
/// offered too and stands for it.
class OptionSelect extends StatelessWidget {
  const OptionSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.noneValue,
  });

  final List<FormOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  /// The value meaning "none" (`'0'` for ids, `''` for text); null when a
  /// choice is required.
  final String? noneValue;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final none = noneValue;
    final items = [
      if (none != null) FormOption(value: none, label: l.selectNone),
      ...options,
      // A value the list lacks (removed, or not yet loaded) still shows.
      if (value != none && !options.any((o) => o.value == value))
        FormOption(value: value, label: '#$value'),
    ];
    return SearchableDropdownField<FormOption>(
      items: items,
      value: items.where((o) => o.value == value).firstOrNull,
      labelOf: (o) => o.label,
      searchHint: l.searchOptions,
      emptyLabel: l.noMatches,
      hintText: l.selectNone,
      onChanged: (o) => onChanged(o.value),
    );
  }
}

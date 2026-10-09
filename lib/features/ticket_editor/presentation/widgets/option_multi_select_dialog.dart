import 'package:flutter/material.dart';

import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../l10n/app_localizations.dart';
import 'option_check_list.dart';

/// A searchable checklist of [options]; pops the picked values, in the
/// options' order.
class OptionMultiSelectDialog extends StatefulWidget {
  const OptionMultiSelectDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<FormOption> options;
  final List<String> selected;

  @override
  State<OptionMultiSelectDialog> createState() =>
      _OptionMultiSelectDialogState();
}

class _OptionMultiSelectDialogState extends State<OptionMultiSelectDialog> {
  late final Set<String> _picked = {...widget.selected};
  String _query = '';

  void _toggle(String value) => setState(
    () => _picked.contains(value) ? _picked.remove(value) : _picked.add(value),
  );

  List<String> get _result => [
    for (final o in widget.options)
      if (_picked.contains(o.value)) o.value,
    // Picks the list does not have (yet) are kept.
    for (final v in widget.selected)
      if (!widget.options.any((o) => o.value == v)) v,
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (query.isEmpty || o.label.toLowerCase().contains(query)) o,
    ];
    return AppDialogFrame(
      title: widget.title,
      maxHeight: s.xl6 * 15,
      headerTrailing: _picked.isEmpty
          ? null
          : Text(
              l.selectSome(_picked.length),
              style: context.typography.bodySm.copyWith(color: c.accent),
            ),
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          onPressed: () => Navigator.pop(context, _result),
          child: Text(l.save),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: s.xl3),
            child: OptionSearchBox(
              hint: l.searchOptions,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(height: s.md),
          Flexible(
            child: OptionCheckList(
              options: shown,
              picked: _picked,
              emptyLabel: l.noMatches,
              onToggle: _toggle,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (query.isEmpty || o.label.toLowerCase().contains(query)) o,
    ];
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: s.xl6 * 10,
        height: s.xl6 * 10,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(hintText: l.searchOptions),
              onChanged: (v) => setState(() => _query = v),
            ),
            SizedBox(height: s.md),
            Expanded(
              child: ListView(
                children: [
                  for (final o in shown)
                    CheckboxListTile(
                      dense: true,
                      value: _picked.contains(o.value),
                      title: Text(o.label),
                      onChanged: (on) => setState(
                        () => on == true
                            ? _picked.add(o.value)
                            : _picked.remove(o.value),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, [
            for (final o in widget.options)
              if (_picked.contains(o.value)) o.value,
            // Picks the list does not have (yet) are kept.
            for (final v in widget.selected)
              if (!widget.options.any((o) => o.value == v)) v,
          ]),
          child: Text(l.save),
        ),
      ],
    );
  }
}

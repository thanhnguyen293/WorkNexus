import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import 'editor_chip.dart';
import 'option_multi_select_dialog.dart';

/// A pick of any number of [options], shown as removable chips; tapping the
/// field opens a searchable checklist.
class OptionMultiSelect extends StatelessWidget {
  const OptionMultiSelect({
    super.key,
    required this.options,
    required this.values,
    required this.onChanged,
    required this.title,
  });

  final List<FormOption> options;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  /// The checklist's heading.
  final String title;

  String _label(String value) =>
      options.where((o) => o.value == value).firstOrNull?.label ?? value;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (_) => OptionMultiSelectDialog(
        title: title,
        options: options,
        selected: values,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.md);
    return HoverSurface(
      onTap: () => _pick(context),
      constraints: BoxConstraints(minHeight: s.xl6),
      padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.sm),
      color: c.surfaceSubtle,
      borderRadius: radius,
      border: Border.all(color: c.border),
      child: Row(
        children: [
          Expanded(
            child: values.isEmpty
                ? Text(
                    AppL10n.of(context).selectNone,
                    style: context.typography.bodySm.copyWith(
                      color: c.textTertiary,
                    ),
                  )
                : Wrap(
                    spacing: s.sm,
                    runSpacing: s.sm,
                    children: [
                      for (final value in values)
                        EditorChip(
                          label: _label(value),
                          onRemove: () => onChanged([
                            for (final v in values)
                              if (v != value) v,
                          ]),
                        ),
                    ],
                  ),
          ),
          Icon(
            PhosphorIconsLight.caretDown,
            size: s.xl3,
            color: c.textTertiary,
          ),
        ],
      ),
    );
  }
}

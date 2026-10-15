import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../shared/detail/presentation/widgets/action_dialog_scaffold.dart';

/// A labelled field for a number of hours.
class TaskHoursField extends StatelessWidget {
  const TaskHoursField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
          ],
          style: context.typography.body.copyWith(
            color: context.colors.textPrimary,
          ),
          decoration: appInputDecoration(context),
        ),
      ],
    );
  }
}

/// Hours typed in a field: 0 when empty, NaN (refused) when not a number.
double parseHours(String text) {
  final value = text.trim().replaceAll(',', '.');
  return value.isEmpty ? 0 : double.tryParse(value) ?? double.nan;
}

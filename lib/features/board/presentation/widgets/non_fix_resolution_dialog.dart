import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/value_objects/zentao_bug_column.dart';

class NonFixResolutionDialog extends StatefulWidget {
  const NonFixResolutionDialog({super.key});

  @override
  State<NonFixResolutionDialog> createState() => _NonFixResolutionDialogState();
}

class _NonFixResolutionDialogState extends State<NonFixResolutionDialog> {
  String? _resolution;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text(
        'Resolve as Non-Fix',
        style: context.typography.title.copyWith(color: c.textPrimary),
      ),
      content: DropdownButtonFormField<String>(
        initialValue: _resolution,
        isExpanded: true,
        dropdownColor: c.surface,
        decoration: InputDecoration(
          filled: true,
          fillColor: c.surfaceSubtle,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.radii.md),
            borderSide: BorderSide(color: c.border),
          ),
        ),
        hint: Text(
          'Select a reason',
          style: context.typography.body.copyWith(color: c.textTertiary),
        ),
        style: context.typography.body.copyWith(color: c.textPrimary),
        items: [
          for (final entry in zentaoNonFixResolutionLabels.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (value) => setState(() => _resolution = value),
      ),
      actions: [
        AppButton.textNeutral(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton.filled(
          onPressed: _resolution == null
              ? null
              : () => Navigator.of(context).pop(_resolution),
          child: const Text('Resolve'),
        ),
      ],
    );
  }
}

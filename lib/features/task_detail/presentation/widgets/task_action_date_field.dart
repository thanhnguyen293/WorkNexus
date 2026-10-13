import 'package:flutter/material.dart';

import '../../../../core/widgets/app_date_field.dart';
import 'action_dialog_scaffold.dart';

/// A labelled date and time (to the minute), as ZenTao's task forms take
/// "actual begin / end", in the app's date field. A disabled field only
/// shows its value, as ZenTao locks a begin that is already recorded.
class TaskActionDateField extends StatelessWidget {
  const TaskActionDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      AppDateField(
        value: value,
        withTime: true,
        enabled: enabled,
        // Never cleared (not clearable), so a null cannot come back.
        onChanged: (picked) {
          if (picked != null) onChanged(picked);
        },
      ),
    ],
  );
}

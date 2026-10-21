import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_date_field.dart';

/// A ZenTao form date (`Y-m-d`, empty for none) in the app's date field:
/// clearable, with quick picks for the usual deadlines.
class EditorDateInput extends StatelessWidget {
  const EditorDateInput({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => AppDateField(
    value: DateTime.tryParse(value),
    clearable: true,
    onChanged: (day) => onChanged(
      day == null ? '' : DateFormat('yyyy-MM-dd').format(day.toLocal()),
    ),
  );
}

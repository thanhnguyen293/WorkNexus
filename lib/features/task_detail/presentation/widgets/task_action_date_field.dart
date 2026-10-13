import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import 'action_dialog_scaffold.dart';

/// A labelled date and time (to the minute) picked with the date then the time picker,
/// as ZenTao's task forms take "actual begin / end". A disabled field only
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

  Future<void> _pick(BuildContext context) async {
    final day = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(value.year - 10),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null) return;
    onChanged(DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final ink = enabled ? c.textPrimary : c.textTertiary;
    final field = HoverSurface(
      onTap: enabled ? () => _pick(context) : null,
      enabled: enabled,
      height: s.xl6,
      padding: EdgeInsets.symmetric(horizontal: s.lg),
      color: c.surfaceSubtle,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: Border.all(color: c.border),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('yyyy-MM-dd HH:mm').format(value),
              style: context.typography.body.copyWith(color: ink),
            ),
          ),
          Icon(
            LucideIcons.calendar300,
            size: context.sizes.iconMd,
            color: c.textTertiary,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [FieldLabel(label), field],
    );
  }
}

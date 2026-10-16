import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A one-tap pick above the calendar ("Today", "Now"…).
typedef AppDateQuickPick = ({String label, DateTime value});

/// What [AppDateField] drops down: quick picks over a month calendar in the
/// app's colors, then [footer] (the time row when a time is picked too).
class AppDatePickerPanel extends StatelessWidget {
  const AppDatePickerPanel({
    super.key,
    required this.picked,
    required this.onPickDay,
    required this.onQuickPick,
    this.quickPicks = const [],
    this.footer,
  });

  final DateTime? picked;

  /// A day tapped in the calendar (midnight; the caller keeps any time).
  final ValueChanged<DateTime> onPickDay;
  final ValueChanged<DateTime> onQuickPick;
  final List<AppDateQuickPick> quickPicks;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = this.picked?.toLocal();
    final day = picked == null
        ? null
        : DateTime(picked.year, picked.month, picked.day);
    // Wide enough to reach the picked day even when it is far back.
    final from = math.min(day?.year ?? now.year, now.year) - 10;
    final footer = this.footer;
    return SizedBox(
      width: s.xl6 * 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (quickPicks.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(s.xl, s.xl, s.xl, s.xs),
              child: Wrap(
                spacing: s.sm,
                runSpacing: s.sm,
                children: [
                  for (final pick in quickPicks)
                    _QuickPick(
                      label: pick.label,
                      selected: picked == pick.value,
                      onTap: () => onQuickPick(pick.value),
                    ),
                ],
              ),
            ),
          _ThemedCalendar(
            // A pick made outside the calendar (a quick pick) moves it.
            key: ValueKey(day),
            initialDate: day ?? today,
            firstDate: DateTime(from),
            lastDate: DateTime(now.year + 10),
            onDateChanged: onPickDay,
          ),
          if (footer != null)
            Padding(
              padding: EdgeInsets.fromLTRB(s.xl, 0, s.xl, s.xl),
              child: footer,
            ),
        ],
      ),
    );
  }
}

/// Material's month calendar, recoloured with the app's tokens.
class _ThemedCalendar extends StatelessWidget {
  const _ThemedCalendar({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: c.accent,
          onPrimary: c.onAccent,
          onSurface: c.textPrimary,
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: c.card,
          dayStyle: context.typography.bodySm,
          weekdayStyle: context.typography.captionStrong.copyWith(
            color: c.textTertiary,
          ),
          yearStyle: context.typography.bodySm,
          subHeaderForegroundColor: c.textPrimary,
          todayBorder: BorderSide(color: c.accent),
          // Selected wins over "today": accent ink on the accent fill would
          // leave a picked today blank.
          todayForegroundColor: _selectedOr(c.onAccent, c.accent),
          todayBackgroundColor: _selectedOr(c.accent, null),
          dayForegroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? c.onAccent
                : states.contains(WidgetState.disabled)
                ? c.textTertiary
                : c.textPrimary,
          ),
          dayBackgroundColor: _selectedOr(c.accent, null),
          dayOverlayColor: WidgetStatePropertyAll(c.hoverFill),
          dayShape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
            ),
          ),
        ),
      ),
      child: CalendarDatePicker(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        onDateChanged: onDateChanged,
      ),
    );
  }
}

class _QuickPick extends StatelessWidget {
  const _QuickPick({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.pill);
    return Material(
      color: selected ? c.mixT(c.accent, 0.14) : c.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? c.mixT(c.accent, 0.5) : c.border),
      ),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.xs),
          child: Text(
            label,
            style: context.typography.bodySmStrong.copyWith(
              color: selected ? c.accent : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// [selected] for the picked day, [otherwise] for the rest.
WidgetStateProperty<Color?> _selectedOr(Color selected, Color? otherwise) =>
    WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? selected : otherwise,
    );

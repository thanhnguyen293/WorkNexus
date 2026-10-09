import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// A date (`Y-m-d`, empty for none) picked from a calendar that drops down
/// under the field, with quick picks for the usual deadlines.
class EditorDateInput extends StatefulWidget {
  const EditorDateInput({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<EditorDateInput> createState() => _EditorDateInputState();
}

class _EditorDateInputState extends State<EditorDateInput> {
  final _menu = MenuController();

  void _pick(DateTime? day) {
    _menu.close();
    widget.onChanged(day == null ? '' : DateFormat('yyyy-MM-dd').format(day));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final picked = DateTime.tryParse(widget.value);
    final locale = Localizations.localeOf(context).toString();
    final radius = BorderRadius.circular(context.radii.md);
    return LayoutBuilder(
      builder: (context, box) => MenuAnchor(
        controller: _menu,
        alignmentOffset: Offset(0, s.xs),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(6),
          shadowColor: WidgetStatePropertyAll(c.scrim.withValues(alpha: 0.3)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.radii.lg),
              side: BorderSide(color: c.border),
            ),
          ),
        ),
        menuChildren: [
          // The calendar scrolls on its own; the menu's scrollbar would
          // fight it over the primary controller.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: PrimaryScrollController.none(
              child: _Calendar(picked: picked, onPick: _pick),
            ),
          ),
        ],
        builder: (context, menu, _) => InkWell(
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          borderRadius: radius,
          child: Container(
            height: s.xl6,
            padding: EdgeInsets.only(left: s.lg),
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              borderRadius: radius,
              border: Border.all(color: menu.isOpen ? c.accent : c.border),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsLight.calendarBlank,
                  size: s.xl3,
                  color: picked == null ? c.textTertiary : c.accent,
                ),
                SizedBox(width: s.md),
                Expanded(
                  child: Text(
                    picked == null
                        ? AppL10n.of(context).selectNone
                        : DateFormat.yMMMEd(locale).format(picked),
                    style: context.typography.bodySm.copyWith(
                      color: picked == null ? c.textTertiary : c.textPrimary,
                    ),
                  ),
                ),
                if (picked != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    color: c.textTertiary,
                    icon: Icon(PhosphorIconsLight.x, size: s.xl2),
                    onPressed: () => _pick(null),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The drop-down: quick picks over a month calendar in the app's colors.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.picked, required this.onPick});

  final DateTime? picked;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final quick = [
      (l.datePickToday, today),
      (l.datePickTomorrow, today.add(const Duration(days: 1))),
      (l.datePickNextWeek, today.add(const Duration(days: 7))),
    ];
    final theme = Theme.of(context);
    return SizedBox(
      width: s.xl6 * 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(s.xl, s.xl, s.xl, s.xs),
            child: Wrap(
              spacing: s.sm,
              runSpacing: s.sm,
              children: [
                for (final (label, day) in quick)
                  _QuickPick(
                    label: label,
                    selected: picked == day,
                    onTap: () => onPick(day),
                  ),
              ],
            ),
          ),
          Theme(
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
                todayBorder: BorderSide(color: c.accent),
                todayForegroundColor: WidgetStatePropertyAll(c.accent),
                dayShape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.radii.md),
                  ),
                ),
              ),
            ),
            child: CalendarDatePicker(
              initialDate: picked ?? today,
              firstDate: DateTime(now.year - 10),
              lastDate: DateTime(now.year + 10),
              onDateChanged: onPick,
            ),
          ),
        ],
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

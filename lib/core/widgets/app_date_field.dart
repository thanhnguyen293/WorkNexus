import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../util/relative_time.dart';
import 'app_date_picker_panel.dart';
import 'app_date_time_columns.dart';
import 'app_icon_button.dart';
import 'hover_surface.dart';

/// The app's date field: a calendar drops down under it, in the app's
/// colors, with quick picks for the usual dates. The value reads in the
/// app-wide date format (Quick Settings).
///
/// With [withTime] it holds a date and a time to the minute: the drop-down
/// gains a time row and a "Now" pick, and stays open while a day is picked so
/// the time can follow. Without it a pick closes it.
class AppDateField extends StatefulWidget {
  const AppDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.withTime = false,
    this.clearable = false,
    this.enabled = true,
  });

  final DateTime? value;

  /// Null only when [clearable] and the user clears the date.
  final ValueChanged<DateTime?> onChanged;
  final bool withTime;
  final bool clearable;

  /// Off: only shows the value (e.g. one the server already recorded).
  final bool enabled;

  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState extends State<AppDateField> {
  final _menu = MenuController();

  void _set(DateTime? value, {required bool close}) {
    if (close) _menu.close();
    widget.onChanged(value);
  }

  /// A calendar day, keeping the time already picked (or now's).
  void _pickDay(DateTime day) {
    if (!widget.withTime) return _set(day, close: true);
    final time = widget.value?.toLocal() ?? DateTime.now();
    _set(
      DateTime(day.year, day.month, day.day, time.hour, time.minute),
      close: false,
    );
  }

  void _pickTime(TimeOfDay time) {
    final day = widget.value?.toLocal() ?? DateTime.now();
    _set(
      DateTime(day.year, day.month, day.day, time.hour, time.minute),
      close: false,
    );
  }

  List<AppDateQuickPick> _quickPicks(AppL10n l) {
    final now = DateTime.now();
    if (widget.withTime) {
      return [
        (
          label: l.datePickNow,
          value: DateTime(now.year, now.month, now.day, now.hour, now.minute),
        ),
      ];
    }
    final today = DateTime(now.year, now.month, now.day);
    return [
      (label: l.datePickToday, value: today),
      (label: l.datePickTomorrow, value: today.add(const Duration(days: 1))),
      (label: l.datePickNextWeek, value: today.add(const Duration(days: 7))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final value = widget.value;
    return MenuAnchor(
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
        // The calendar scrolls on its own; the menu's scrollbar would fight
        // it over the primary controller.
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: PrimaryScrollController.none(
            child: AppDatePickerPanel(
              picked: value,
              onPickDay: _pickDay,
              onQuickPick: (v) => _set(v, close: true),
              quickPicks: _quickPicks(l),
              sideWidget: widget.withTime
                  ? AppDateTimeColumns(
                      time: TimeOfDay.fromDateTime(
                        (value?.toLocal()) ?? DateTime.now(),
                      ),
                      onChanged: _pickTime,
                    )
                  : null,
            ),
          ),
        ),
      ],
      builder: (context, menu, _) => _DateButton(
        value: value,
        withTime: widget.withTime,
        enabled: widget.enabled,
        open: menu.isOpen,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        onClear: widget.clearable && widget.enabled && value != null
            ? () => _set(null, close: true)
            : null,
      ),
    );
  }
}

/// The closed field: the date (and time) picked, or "None".
class _DateButton extends ConsumerWidget {
  const _DateButton({
    required this.value,
    required this.withTime,
    required this.enabled,
    required this.open,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? value;
  final bool withTime;
  final bool enabled;
  final bool open;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final format = ref.watch(appSettingsProvider.select((s) => s.dateFormat));
    final value = this.value;
    final ink = !enabled || value == null ? c.textTertiary : c.textPrimary;
    final text = value == null
        ? l.selectNone
        : formatDate(context, value, format: format, withTime: withTime);
    final clear = onClear;
    return HoverSurface(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      height: s.xl6,
      padding: EdgeInsets.only(left: s.lg, right: clear == null ? s.lg : 0),
      color: c.surfaceSubtle,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: Border.all(color: open ? c.accent : c.border),
      child: Row(
        children: [
          Icon(
            LucideIcons.calendar300,
            size: context.sizes.iconMd,
            color: enabled && value != null ? c.accent : c.textTertiary,
          ),
          SizedBox(width: s.md),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodySm.copyWith(color: ink),
            ),
          ),
          if (clear != null)
            AppIconButton(
              icon: LucideIcons.x300,
              tooltip: l.dateClear,
              size: AppIconButtonSize.small,
              color: c.textTertiary,
              onPressed: clear,
            ),
        ],
      ),
    );
  }
}

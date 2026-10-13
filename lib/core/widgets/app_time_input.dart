import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_input_decoration.dart';

/// A time of day typed as `HH:mm` (24-hour). Every valid entry is reported at
/// once; leaving the field with an unfinished one puts the last valid time
/// back. ↑ / ↓ step the minutes.
class AppTimeInput extends StatefulWidget {
  const AppTimeInput({super.key, required this.value, required this.onChanged});

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  State<AppTimeInput> createState() => _AppTimeInputState();
}

class _AppTimeInputState extends State<AppTimeInput> {
  late final _text = TextEditingController(text: formatTimeOfDay(widget.value));
  late final _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _show(widget.value);
    });
  }

  @override
  void didUpdateWidget(AppTimeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Set from outside (e.g. "Now"): show it, unless it is what was typed.
    if (parseTimeOfDay(_text.text) != widget.value) _show(widget.value);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _show(TimeOfDay time) {
    final text = formatTimeOfDay(time);
    if (_text.text == text) return;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onChanged(String text) {
    final time = parseTimeOfDay(text);
    if (time != null && time != widget.value) widget.onChanged(time);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => 1,
      LogicalKeyboardKey.arrowDown => -1,
      _ => 0,
    };
    if (step == 0) return KeyEventResult.ignored;
    final v = widget.value;
    // Wraps around midnight, as a clock does.
    final minutes = (v.hour * 60 + v.minute + step) % (24 * 60);
    final next = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    _show(next);
    widget.onChanged(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: context.spacing.xl6 * 2,
    child: TextField(
      controller: _text,
      focusNode: _focus,
      textAlign: TextAlign.center,
      style: context.typography.body,
      keyboardType: TextInputType.datetime,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
        LengthLimitingTextInputFormatter(5),
      ],
      decoration: appInputDecoration(
        context,
        hint: AppL10n.of(context).dateTimeHint,
      ),
      onChanged: _onChanged,
    ),
  );
}

/// [time] as `HH:mm`.
String formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// `HH:mm`, `H:mm` or `HHmm` as a time of day; null when it is not one.
TimeOfDay? parseTimeOfDay(String text) {
  final match = RegExp(r'^(\d{1,2}):?(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

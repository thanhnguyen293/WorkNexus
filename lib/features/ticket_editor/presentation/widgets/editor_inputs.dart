import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The editor's text inputs share one look.
InputDecoration editorInputDecoration(BuildContext context, {String? hint}) {
  final c = context.colors;
  final s = context.spacing;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(context.radii.md),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: c.surfaceSubtle,
    hintText: hint,
    hintStyle: context.typography.bodySm.copyWith(color: c.textTertiary),
    contentPadding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.md),
    border: border(c.border),
    enabledBorder: border(c.border),
    focusedBorder: border(c.accent),
  );
}

/// A one-line text input that reports each change; its text is set once, from
/// [initial].
class EditorTextInput extends StatefulWidget {
  const EditorTextInput({
    super.key,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.numeric = false,
    this.big = false,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final String? hint;

  /// Accepts hours (digits and one decimal point) only.
  final bool numeric;

  /// The title's larger text.
  final bool big;

  @override
  State<EditorTextInput> createState() => _EditorTextInputState();
}

class _EditorTextInputState extends State<EditorTextInput> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = context.typography;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: widget.numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      inputFormatters: widget.numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      style: (widget.big ? type.bodySmStrong : type.bodySm).copyWith(
        color: context.colors.textPrimary,
      ),
      decoration: editorInputDecoration(context, hint: widget.hint),
    );
  }
}

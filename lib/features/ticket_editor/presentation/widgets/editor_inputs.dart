import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_input_decoration.dart';

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
      decoration: appInputDecoration(
        context,
        hint: widget.hint,
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.spacing.lg,
          vertical: context.spacing.md,
        ),
      ),
    );
  }
}

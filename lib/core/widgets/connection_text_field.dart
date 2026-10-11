import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_input_decoration.dart';

/// A labeled text field in the app's input style: the connection dialogs
/// (ZenTao / GitLab) and the editor's link dialog share it.
class ConnectionTextField extends StatelessWidget {
  const ConnectionTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.onChanged,
    this.trailing,
    this.autofocus = false,
    this.errorText,
    this.onSubmitted,
    this.prefixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final ValueChanged<String>? onChanged;

  /// Optional action shown at the trailing edge of the label row (e.g. a
  /// "Generate token" link).
  final Widget? trailing;

  final bool autofocus;

  /// Shown under the field, which turns to the error colour, when set.
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.typography.captionStrong.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        SizedBox(height: context.spacing.xs),
        TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: context.typography.body.copyWith(color: c.textPrimary),
          decoration: appInputDecoration(
            context,
            hint: hint,
            errorText: errorText,
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }
}

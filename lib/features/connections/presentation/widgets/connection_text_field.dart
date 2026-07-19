import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A labeled text field used by the connection dialogs (ZenTao / GitLab).
/// Extracted so both dialogs share one styling of the label + input.
class ConnectionTextField extends StatelessWidget {
  const ConnectionTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.typography.captionStrong.copyWith(
            color: c.textSecondary,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: context.typography.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.surfaceSubtle,
            hintText: hint,
            hintStyle: context.typography.body.copyWith(color: c.textTertiary),
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.spacing.lg,
              vertical: context.spacing.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
              borderSide: BorderSide(color: c.accent),
            ),
          ),
        ),
      ],
    );
  }
}

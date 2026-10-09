import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The chat list's input look (filled, hairline border), for the new-chat
/// dialog's search and group-name fields.
InputDecoration chatFieldDecoration(
  BuildContext context, {
  required String hint,
  IconData? icon,
}) {
  final c = context.colors;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(context.radii.md),
    borderSide: BorderSide(color: c.border),
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: c.background,
    hintText: hint,
    hintStyle: context.typography.body.copyWith(color: c.textTertiary),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: context.spacing.xl3, color: c.textTertiary),
    contentPadding: EdgeInsets.symmetric(
      vertical: context.spacing.lg,
      horizontal: context.spacing.lg,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: c.accent)),
  );
}

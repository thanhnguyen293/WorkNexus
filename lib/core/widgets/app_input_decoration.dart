import 'package:flutter/material.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The one text-input look: a filled inset with a hairline that turns accent
/// on focus and error-red on [errorText]. Every hand-styled `TextField` uses
/// this rather than its own `OutlineInputBorder` set.
///
/// [fillColor] swaps the inset for fields that sit on an inset already (e.g.
/// the chat list, where the field takes the window background).
InputDecoration appInputDecoration(
  BuildContext context, {
  String? hint,
  IconData? prefixIcon,
  Widget? suffix,
  String? errorText,
  Color? fillColor,
  EdgeInsetsGeometry? contentPadding,
  BoxConstraints? prefixIconConstraints,
  BoxConstraints? suffixIconConstraints,
}) {
  final c = context.colors;
  final s = context.spacing;
  final t = context.typography;
  OutlineInputBorder border(Color color, [double? width]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(context.radii.md),
    borderSide: BorderSide(
      color: color,
      width: width ?? context.borders.hairline,
    ),
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: fillColor ?? c.surfaceSubtle,
    hoverColor: Colors.transparent,
    hintText: hint,
    hintStyle: t.body.copyWith(color: c.textTertiary),
    errorText: errorText,
    errorStyle: t.caption.copyWith(color: c.error),
    errorMaxLines: 3,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: context.sizes.iconSm, color: c.textTertiary),
    prefixIconConstraints:
        prefixIconConstraints ??
        BoxConstraints(
          minWidth: context.sizes.controlMd,
          minHeight: context.sizes.iconSm,
        ),
    suffixIcon: suffix,
    suffixIconConstraints:
        suffixIconConstraints ??
        BoxConstraints(
          minWidth: context.sizes.controlSm,
          minHeight: context.sizes.iconSm,
        ),
    contentPadding:
        contentPadding ??
        EdgeInsets.symmetric(horizontal: s.lg, vertical: s.lg),
    border: border(c.border),
    enabledBorder: border(c.border),
    disabledBorder: border(c.border.withValues(alpha: 0.5)),
    focusedBorder: border(c.accent, context.borders.medium),
    errorBorder: border(c.error),
    focusedErrorBorder: border(c.error, context.borders.medium),
  );
}

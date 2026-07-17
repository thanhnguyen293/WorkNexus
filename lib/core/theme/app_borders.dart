import 'package:flutter/material.dart';

import 'app_colors.dart';

/// **Border** tokens exposed to the widget tree via [ThemeExtension].
///
/// Carries stroke widths plus [showOutline] (from the flat/outline surface
/// style). Read widths with `context.borders`; for the common composed cases
/// prefer `context.hairlineSide` / `context.cardBorder`, which pull the border
/// color from [AppColors] for you.
@immutable
class AppBorders extends ThemeExtension<AppBorders> {
  const AppBorders({required this.showOutline});

  /// Whether surfaces draw a 1px outline (flat surfaces get none).
  final bool showOutline;

  double get hairline => 1.0; // default divider / border
  double get medium => 1.5; // popover outline
  double get thick => 2.0; // active tab indicator
  double get accent => 3.0; // workspace-color edge stripe

  @override
  AppBorders copyWith({bool? showOutline}) =>
      AppBorders(showOutline: showOutline ?? this.showOutline);

  @override
  AppBorders lerp(covariant AppBorders? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessors: `context.borders`, plus composed helpers that read the
/// border color from [AppColors].
extension AppBordersContext on BuildContext {
  AppBorders get borders => Theme.of(this).extension<AppBorders>()!;

  /// A 1px `border`-colored side (replaces the old `AppTokens.hairline`).
  BorderSide get hairlineSide =>
      BorderSide(color: colors.border, width: borders.hairline);

  /// Outline surfaces get a 1px `border`; flat surfaces get none (replaces the
  /// old `AppTokens.cardBorder`).
  BoxBorder? get cardBorder =>
      borders.showOutline ? Border.all(color: colors.border) : null;
}

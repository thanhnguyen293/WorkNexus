import 'package:flutter/material.dart';

import 'app_palette.dart';

/// **Spacing** scale exposed to the widget tree via [ThemeExtension].
///
/// A t-shirt scale for gaps/padding, plus [cardPadding] which is derived from
/// the active [AppDensity]. Read it with the `context.spacing` getter.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({required this.cardPadding});

  /// Density-derived card inset (moved from the old `AppTokens.cardPadding`).
  factory AppSpacing.forDensity(AppDensity density) => AppSpacing(
    cardPadding: density == AppDensity.compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );

  final EdgeInsets cardPadding;

  double get none => 0;
  double get xxs => 2;
  double get xs => 4;
  double get sm => 6;
  double get md => 8;
  double get lg => 10;
  double get xl => 12;
  double get xl2 => 14;
  double get xl3 => 16;
  double get xl4 => 20;
  double get xl5 => 24;
  double get xl6 => 40;

  @override
  AppSpacing copyWith({EdgeInsets? cardPadding}) =>
      AppSpacing(cardPadding: cardPadding ?? this.cardPadding);

  @override
  AppSpacing lerp(covariant AppSpacing? other, double t) {
    if (other == null) return this;
    return AppSpacing(
      cardPadding: EdgeInsets.lerp(cardPadding, other.cardPadding, t)!,
    );
  }
}

/// Convenience accessor: `context.spacing`.
extension AppSpacingContext on BuildContext {
  AppSpacing get spacing => Theme.of(this).extension<AppSpacing>()!;
}

import 'package:flutter/material.dart';

/// **Corner-radius** scale exposed to the widget tree via [ThemeExtension].
///
/// Constant across theme variants (kept an extension for consistency and future
/// theming). Read it with the `context.radii` getter.
@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii();

  double get none => 0;
  double get dot => 2; // tiny status dots
  double get xs => 4;
  double get sm => 6;
  double get md => 8;
  double get card => 10; // ticket card
  double get lg => 12; // dialogs, columns, popovers
  double get xl => 20; // search fields / large pills
  double get pill => 999; // fully rounded

  @override
  AppRadii copyWith() => const AppRadii();

  @override
  AppRadii lerp(covariant AppRadii? other, double t) => other ?? this;
}

/// Convenience accessor: `context.radii`.
extension AppRadiiContext on BuildContext {
  AppRadii get radii => Theme.of(this).extension<AppRadii>()!;
}

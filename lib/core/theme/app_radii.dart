import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The user-adjustable [AppRadii.component] radius presets (logical pixels).
/// The settings slider snaps to exactly these values — square → fully rounded.
const List<double> kComponentRadiusPresets = <double>[0, 4, 8, 12, 16];
const double kComponentRadiusMin = 0;
const double kComponentRadiusMax = 16;
const double kComponentRadiusDefault = 8;

/// Snaps an arbitrary [value] (e.g. legacy/stored) to the nearest preset.
double snapComponentRadius(double value) {
  var best = kComponentRadiusPresets.first;
  for (final p in kComponentRadiusPresets) {
    if ((value - p).abs() < (value - best).abs()) best = p;
  }
  return best;
}

/// **Corner-radius** scale exposed to the widget tree via [ThemeExtension].
///
/// The fixed scale (`xs`…`pill`) is constant across theme variants. [component]
/// is the *user-adjustable* radius used by design-system components (buttons,
/// and any widget that opts into `context.radii.component`); it is driven by the
/// settings slider. Read it with the `context.radii` getter.
@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({this.component = kComponentRadiusDefault});

  /// User-adjustable component radius (settings slider).
  final double component;

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
  AppRadii copyWith({double? component}) =>
      AppRadii(component: component ?? this.component);

  @override
  AppRadii lerp(covariant AppRadii? other, double t) {
    if (other == null) return this;
    return AppRadii(
      component: lerpDouble(component, other.component, t) ?? component,
    );
  }
}

/// Convenience accessor: `context.radii`.
extension AppRadiiContext on BuildContext {
  AppRadii get radii => Theme.of(this).extension<AppRadii>()!;
}

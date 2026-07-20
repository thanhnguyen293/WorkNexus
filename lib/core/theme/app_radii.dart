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
/// [component] is the *user-adjustable* base radius driven by the settings
/// slider. The whole ramp (`xs`…`xl`) is derived from it as fixed multiples, so
/// moving the slider re-rounds **every** design-system surface (cards, dialogs,
/// inputs, popovers, badges, menus, banners, buttons) in lockstep while keeping
/// their relative hierarchy. The multipliers are anchored so the default
/// ([kComponentRadiusDefault] = 8) reproduces the historical fixed values
/// exactly. Only [none], [dot] and [pill] are semantic constants that never
/// scale. Read it with the `context.radii` getter.
@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({this.component = kComponentRadiusDefault});

  /// User-adjustable base radius (settings slider). Equals [md].
  final double component;

  double get none => 0;
  double get dot => 2; // tiny status dots — always subtly rounded
  double get xs => component * 0.5; // 4 at default
  double get sm => component * 0.75; // 6 at default
  double get md => component; // 8 at default
  double get card => component * 1.25; // 10 — ticket card
  double get lg => component * 1.5; // 12 — dialogs, columns, popovers
  double get xl => component * 2.5; // 20 — search fields / large pills
  double get pill => 999; // fully rounded — pills, avatars

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

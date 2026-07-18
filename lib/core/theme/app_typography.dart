import 'package:flutter/material.dart';

import 'fonts.dart';

/// Named **typography** tokens exposed to the widget tree via [ThemeExtension].
///
/// Styles are **color-agnostic** — apply a color role at the call site, e.g.
/// `context.typography.secondary.copyWith(color: context.colors.textSecondary)`.
/// Sans styles omit `fontFamily` so they inherit [ThemeData.fontFamily] (the
/// user-selected UI font); mono styles pin [kMonoFont]. Read it with the
/// `context.typography` getter.
///
/// The ramp is identical across theme variants, so [lerp]/[copyWith] are no-ops.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography();

  // ---- Titles ----
  TextStyle get displayLg =>
      const TextStyle(fontSize: 28, fontWeight: FontWeight.w600);
  TextStyle get display =>
      const TextStyle(fontSize: 22, fontWeight: FontWeight.w600);
  TextStyle get titleLg =>
      const TextStyle(fontSize: 19, fontWeight: FontWeight.w600);
  TextStyle get detailTitle => const TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  TextStyle get title =>
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  TextStyle get titleSm =>
      const TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  TextStyle get cardTitle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.36,
  );
  TextStyle get subtitle =>
      const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);

  // ---- Body ----
  TextStyle get body => const TextStyle(fontSize: 13);
  TextStyle get bodyStrong =>
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  TextStyle get secondary => const TextStyle(fontSize: 12.5);
  TextStyle get secondaryStrong =>
      const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);
  TextStyle get paragraph => const TextStyle(fontSize: 12.5, height: 1.5);
  TextStyle get paragraphSm => const TextStyle(fontSize: 12, height: 1.5);
  TextStyle get bodySm => const TextStyle(fontSize: 12);
  TextStyle get bodySmStrong =>
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  TextStyle get meta => const TextStyle(fontSize: 11.5);
  TextStyle get caption => const TextStyle(fontSize: 11);
  TextStyle get captionStrong =>
      const TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
  TextStyle get captionSm => const TextStyle(fontSize: 10.5);

  // ---- Labels (typically uppercased at the call site) ----
  TextStyle get label => const TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
  TextStyle get labelWide => const TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
  TextStyle get labelLoose => const TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  // ---- Mono (code, refs, ids, timestamps) ----
  TextStyle get mono => const TextStyle(fontSize: 11, fontFamily: kMonoFont);
  TextStyle get monoSm =>
      const TextStyle(fontSize: 10.5, fontFamily: kMonoFont);
  TextStyle get monoXs => const TextStyle(fontSize: 10, fontFamily: kMonoFont);
  TextStyle get monoStrong => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFamily: kMonoFont,
  );

  // ---- Badges (mono, tight line height) ----
  TextStyle get badge => const TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    fontFamily: kMonoFont,
    height: 1,
  );
  TextStyle get badgeLg => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    fontFamily: kMonoFont,
    height: 1,
  );
  TextStyle get badgeSm => const TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
    fontFamily: kMonoFont,
    letterSpacing: 0.2,
    height: 1,
  );

  @override
  AppTypography copyWith() => const AppTypography();

  @override
  AppTypography lerp(covariant AppTypography? other, double t) => other ?? this;
}

/// Convenience accessor: `context.typography`.
extension AppTypographyContext on BuildContext {
  AppTypography get typography => Theme.of(this).extension<AppTypography>()!;
}

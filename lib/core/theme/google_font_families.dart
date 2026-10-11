import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fonts.dart';

/// A font family served by `google_fonts` (downloaded + cached at runtime)
/// rather than bundled in `assets/fonts/`.
///
/// [style] registers the family loader and yields the generated family name;
/// [textTheme] applies the family's full weight ramp across a base [TextTheme].
typedef GoogleFontFamily = ({
  TextStyle Function() style,
  TextTheme Function(TextTheme base) textTheme,
});

/// The entries of `kFontChoices` that are google-fonts-backed, keyed by their
/// marker family name. Everything else is bundled (`Space Grotesk` / `Space
/// Mono`, `Be Vietnam Pro`), a platform family, or the system marker.
///
/// google_fonts names each weight its own family (`…_regular`, `…_700`), so
/// a style that only changes `fontWeight` (Markdown bold, `bodyStrong`) keeps
/// the regular face; a family whose bold must show is bundled instead.
final Map<String, GoogleFontFamily> kGoogleFontFamilies = {
  kGeistMonoFont: (
    style: () => GoogleFonts.geistMono(),
    textTheme: (base) => GoogleFonts.geistMonoTextTheme(base),
  ),
};

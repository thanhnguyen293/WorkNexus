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
/// Mono`), a platform family, or the system marker.
final Map<String, GoogleFontFamily> kGoogleFontFamilies = {
  kVietnamFont: (
    style: () => GoogleFonts.beVietnamPro(),
    textTheme: (base) => GoogleFonts.beVietnamProTextTheme(base),
  ),
  kGeistMonoFont: (
    style: () => GoogleFonts.geistMono(),
    textTheme: (base) => GoogleFonts.geistMonoTextTheme(base),
  ),
};

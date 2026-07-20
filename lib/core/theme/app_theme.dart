import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_borders.dart';
import 'app_button_theme.dart';
import 'app_colors.dart';
import 'app_palette.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'fonts.dart';
import 'google_font_families.dart';

/// Builds a [ThemeData] for the given orthogonal appearance axes.
///
/// Colors come from the [AppPalette]; surface (flat/outline) and density
/// (comfortable/compact) are carried in the [AppTokens] extension and, for
/// density, also reflected in [ThemeData.visualDensity].
ThemeData buildAppTheme({
  required AppThemeVariant variant,
  required SurfaceStyle surface,
  required AppDensity density,
  String fontFamily = kSansFont,
  double componentRadius = kComponentRadiusDefault,
  int? accentColorValue,
}) {
  final p = AppPalette.of(variant);
  final spacing = AppSpacing.forDensity(density);
  final radii = AppRadii(component: componentRadius);
  final borders = AppBorders(showOutline: surface == SurfaceStyle.outline);

  // Effective accent: the user's chosen primary color, or the palette default.
  // Text/selection tints derive from it so a custom accent stays coherent.
  final accent = accentColorValue == null ? p.accent : Color(accentColorValue);
  final onAccent = accentColorValue == null
      ? p.accentTx
      : (accent.computeLuminance() > 0.55 ? p.onColorInk : Colors.white);
  final colors = accentColorValue == null
      ? AppColors.fromPalette(p)
      : AppColors.fromPalette(p).copyWith(
          accent: accent,
          onAccent: onAccent,
          selectionFill: accent.withValues(alpha: 0.14),
          selectionBorder: accent.withValues(alpha: 0.5),
        );
  final requestedFamily = fontFamily.trim();
  // Some families (Be Vietnam Pro, Geist Mono) are served by google_fonts under
  // a generated family name; the rest are bundled/system names used as-is.
  final googleFont = kGoogleFontFamilies[requestedFamily];
  final String? family = requestedFamily.isEmpty
      ? kSansFont
      : requestedFamily == kSystemFont
      ? null
      : googleFont != null
      ? googleFont.style().fontFamily
      : requestedFamily;

  final colorScheme = ColorScheme(
    brightness: p.brightness,
    primary: accent,
    onPrimary: onAccent,
    secondary: accent,
    onSecondary: onAccent,
    error: p.red,
    onError: Colors.white,
    surface: p.panel,
    onSurface: p.tx,
  );

  final platformTypography = Typography.material2021(
    platform: defaultTargetPlatform,
    colorScheme: colorScheme,
  );
  final coloredBase =
      (p.brightness == Brightness.dark
              ? platformTypography.white
              : platformTypography.black)
          .apply(bodyColor: p.tx, displayColor: p.tx);
  // google_fonts registers each family's weight variants across the ramp;
  // other families are applied by name (bundled or system).
  final baseText = googleFont != null
      ? googleFont.textTheme(coloredBase)
      : coloredBase.apply(fontFamily: family);

  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    fontFamily: family,
    // Fall back to the bundled sans if a system family is unavailable.
    fontFamilyFallback: const [kSansFont],
    visualDensity: density == AppDensity.compact
        ? const VisualDensity(horizontal: -1, vertical: -1)
        : VisualDensity.standard,
    textTheme: baseText,
    dividerColor: p.line,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(8),
      thumbColor: WidgetStatePropertyAll(p.tx3.withValues(alpha: 0.4)),
      radius: const Radius.circular(6),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.panel2,
        border: Border.all(color: p.line2),
        borderRadius: BorderRadius.circular(radii.sm),
      ),
      textStyle: TextStyle(color: p.tx, fontSize: 11, fontFamily: family),
    ),
    extensions: [
      colors,
      const AppTypography(),
      spacing,
      radii,
      borders,
      AppButtonTheme.build(colors, borders),
    ],
  );
}

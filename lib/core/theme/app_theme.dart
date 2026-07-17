import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_borders.dart';
import 'app_colors.dart';
import 'app_palette.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'fonts.dart';

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
}) {
  final p = AppPalette.of(variant);
  final colors = AppColors.fromPalette(p);
  final spacing = AppSpacing.forDensity(density);
  final borders = AppBorders(showOutline: surface == SurfaceStyle.outline);
  final requestedFamily = fontFamily.trim();
  final String? family = requestedFamily.isEmpty
      ? kSansFont
      : requestedFamily == kSystemFont
      ? null
      : requestedFamily;

  final colorScheme = ColorScheme(
    brightness: p.brightness,
    primary: p.accent,
    onPrimary: p.accentTx,
    secondary: p.accent,
    onSecondary: p.accentTx,
    error: p.red,
    onError: Colors.white,
    surface: p.panel,
    onSurface: p.tx,
  );

  final platformTypography = Typography.material2021(
    platform: defaultTargetPlatform,
    colorScheme: colorScheme,
  );
  final baseText =
      (p.brightness == Brightness.dark
              ? platformTypography.white
              : platformTypography.black)
          .apply(fontFamily: family, bodyColor: p.tx, displayColor: p.tx);

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
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(color: p.tx, fontSize: 11, fontFamily: family),
    ),
    extensions: [
      colors,
      const AppTypography(),
      spacing,
      const AppRadii(),
      borders,
    ],
  );
}

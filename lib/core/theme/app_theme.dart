import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_borders.dart';
import 'app_button_theme.dart';
import 'app_colors.dart';
import 'app_palette.dart';
import 'app_radii.dart';
import 'app_sizes.dart';
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
  String fontFamily = kVietnamFont,
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
  // Some families (Geist Mono) are served by google_fonts under
  // a generated family name; the rest are bundled/system names used as-is.
  final googleFont = kGoogleFontFamilies[requestedFamily];
  final String? family = requestedFamily.isEmpty
      ? kVietnamFont
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
    // Material 3 tints raised surfaces (menus, dialogs, panels, cards) with
    // `surfaceTint`, which defaults to primary — that put an accent cast on
    // every background. Surfaces stay the palette's neutral greys.
    surfaceTint: Colors.transparent,
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
    // Fall back to the bundled Be Vietnam Pro, then Space Grotesk.
    fontFamilyFallback: const [kVietnamFont, kSansFont],
    visualDensity: density == AppDensity.compact
        ? const VisualDensity(horizontal: -1, vertical: -1)
        : VisualDensity.standard,
    textTheme: baseText,
    dividerColor: p.line,
    // Every tab bar's baseline is the app's hairline, not Material's darker
    // outline colour.
    tabBarTheme: TabBarThemeData(dividerColor: p.line, dividerHeight: 1),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // Every InkWell / ListTile hover reads this. Flutter's default (~4% ink)
    // is invisible on these flat surfaces, so point it at the hover token.
    hoverColor: colors.hoverFill,
    // Keyboard focus must read on flat surfaces too: an accent wash, not the
    // near-invisible default.
    focusColor: accent.withValues(alpha: 0.16),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: 0.28),
      selectionHandleColor: accent,
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: p.panel2,
      circularTrackColor: Colors.transparent,
      strokeWidth: 2,
    ),
    // Raw AlertDialog / Dialog call sites get the same chrome as
    // AppDialogFrame: the panel surface, a hairline and the large radius.
    dialogTheme: DialogThemeData(
      backgroundColor: p.panel,
      surfaceTintColor: Colors.transparent,
      barrierColor: p.scrim.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.lg),
        side: BorderSide(color: p.line),
      ),
      titleTextStyle: const AppTypography().title.copyWith(
        color: p.tx,
        fontFamily: family,
      ),
      contentTextStyle: const AppTypography().body.copyWith(
        color: p.tx2,
        fontFamily: family,
      ),
    ),
    // One floating, inverse-surface toast everywhere a feature shows a
    // SnackBar, instead of Material's full-width bar.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.tx,
      contentTextStyle: const AppTypography().body.copyWith(
        color: p.bg,
        fontFamily: family,
      ),
      // The accent can't be trusted to read on an inverse surface (custom
      // accents included), so the action takes the content ink.
      actionTextColor: p.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.md),
      ),
      elevation: 2,
    ),
    // Flutter 3.44 made Material's tappables default to an "adaptive" cursor:
    // the hand on web only, the arrow on desktop. This is a desktop app whose
    // controls are mostly flat and borderless, so put the hand back wherever
    // a theme can carry it. InkWell has no theme; call sites pass
    // `WidgetStateMouseCursor.clickable` themselves.
    elevatedButtonTheme: const ElevatedButtonThemeData(style: _clickable),
    filledButtonTheme: const FilledButtonThemeData(style: _clickable),
    outlinedButtonTheme: const OutlinedButtonThemeData(style: _clickable),
    textButtonTheme: const TextButtonThemeData(style: _clickable),
    iconButtonTheme: const IconButtonThemeData(style: _clickable),
    menuButtonTheme: const MenuButtonThemeData(style: _clickable),
    segmentedButtonTheme: const SegmentedButtonThemeData(style: _clickable),
    popupMenuTheme: PopupMenuThemeData(
      mouseCursor: WidgetStateMouseCursor.clickable,
      color: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.md),
        side: BorderSide(color: p.line),
      ),
    ),
    checkboxTheme: const CheckboxThemeData(
      mouseCursor: WidgetStateMouseCursor.clickable,
    ),
    radioTheme: const RadioThemeData(
      mouseCursor: WidgetStateMouseCursor.clickable,
    ),
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
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      ),
      waitDuration: const Duration(milliseconds: 400),
      textStyle: const AppTypography().bodySm.copyWith(
        color: p.tx,
        fontFamily: family,
      ),
    ),
    extensions: [
      colors,
      const AppTypography(),
      spacing,
      radii,
      borders,
      const AppSizes(),
      AppButtonTheme.build(colors, borders),
    ],
  );
}

/// The hand over an enabled button, the arrow over a disabled one.
const _clickable = ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable);

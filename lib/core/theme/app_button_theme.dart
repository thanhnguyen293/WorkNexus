import 'package:flutter/material.dart';

import 'app_borders.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Per-variant [ButtonStyle]s for [AppButton], exposed via [ThemeExtension].
///
/// Each style carries only the *visual identity* of a variant (fill, text/icon
/// color, border, hover overlay, disabled treatment). Geometry that varies per
/// call — size (height/padding/text style) and the user-adjustable corner radius
/// (`context.radii.component`) — is layered on by the widget, so one variant
/// style serves every size. Read it with the `context.buttons` getter.
@immutable
class AppButtonTheme extends ThemeExtension<AppButtonTheme> {
  const AppButtonTheme({
    required this.filled,
    required this.filledNeutral,
    required this.outlined,
    required this.outlinedNeutral,
    required this.text,
    required this.textNeutral,
    required this.error,
  });

  /// Builds the variant styles from the semantic color roles + surface style.
  ///
  /// The WorkNexus button language (not a port): flat surfaces, a graduated
  /// state layer (hover < focus < pressed) drawn in the variant's own ink, a
  /// hairline border that tracks the surface style, and a uniform disabled
  /// dimming. Filled variants layer white/ink over the fill; tonal/outlined/text
  /// variants tint with their foreground role.
  factory AppButtonTheme.build(AppColors c, AppBorders b) {
    final neutralSide = b.showOutline ? BorderSide(color: c.border) : null;
    return AppButtonTheme(
      filled: _style(
        foreground: c.onAccent,
        background: c.accent,
        stateLayer: c.onAccent,
      ),
      filledNeutral: _style(
        foreground: c.textPrimary,
        background: c.surfaceSubtle,
        stateLayer: c.textPrimary,
        side: neutralSide ?? BorderSide(color: c.border),
      ),
      outlined: _style(
        foreground: c.accent,
        stateLayer: c.accent,
        side: BorderSide(color: c.mixT(c.accent, 0.45)),
      ),
      outlinedNeutral: _style(
        foreground: c.textPrimary,
        stateLayer: c.textPrimary,
        side: BorderSide(color: c.borderStrong),
      ),
      text: _style(foreground: c.accent, stateLayer: c.accent),
      textNeutral: _style(
        foreground: c.textSecondary,
        stateLayer: c.textPrimary,
      ),
      error: _style(
        foreground: c.onAccent,
        background: c.error,
        stateLayer: c.onAccent,
      ),
    );
  }

  final ButtonStyle filled;
  final ButtonStyle filledNeutral;
  final ButtonStyle outlined;
  final ButtonStyle outlinedNeutral;
  final ButtonStyle text;
  final ButtonStyle textNeutral;
  final ButtonStyle error;

  @override
  AppButtonTheme copyWith({
    ButtonStyle? filled,
    ButtonStyle? filledNeutral,
    ButtonStyle? outlined,
    ButtonStyle? outlinedNeutral,
    ButtonStyle? text,
    ButtonStyle? textNeutral,
    ButtonStyle? error,
  }) {
    return AppButtonTheme(
      filled: filled ?? this.filled,
      filledNeutral: filledNeutral ?? this.filledNeutral,
      outlined: outlined ?? this.outlined,
      outlinedNeutral: outlinedNeutral ?? this.outlinedNeutral,
      text: text ?? this.text,
      textNeutral: textNeutral ?? this.textNeutral,
      error: error ?? this.error,
    );
  }

  @override
  AppButtonTheme lerp(covariant AppButtonTheme? other, double t) {
    if (other == null) return this;
    ButtonStyle l(ButtonStyle a, ButtonStyle b) => ButtonStyle.lerp(a, b, t)!;
    return AppButtonTheme(
      filled: l(filled, other.filled),
      filledNeutral: l(filledNeutral, other.filledNeutral),
      outlined: l(outlined, other.outlined),
      outlinedNeutral: l(outlinedNeutral, other.outlinedNeutral),
      text: l(text, other.text),
      textNeutral: l(textNeutral, other.textNeutral),
      error: l(error, other.error),
    );
  }
}

/// Builds one variant [ButtonStyle]. [background] null → transparent (text /
/// outlined variants); [side] null → borderless. [stateLayer] is the ink the
/// hover/focus/pressed overlay is drawn in — `onAccent` for filled variants (so
/// the fill lightens/darkens), the foreground role otherwise. Size, padding,
/// text style, and shape are applied later by the widget.
ButtonStyle _style({
  required Color foreground,
  required Color stateLayer,
  Color? background,
  BorderSide? side,
}) {
  const disabledAlpha = 0.38;
  final baseBg = background ?? Colors.transparent;
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? foreground.withValues(alpha: disabledAlpha)
          : foreground,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? foreground.withValues(alpha: disabledAlpha)
          : foreground,
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) && background != null
          ? baseBg.withValues(alpha: disabledAlpha)
          : baseBg,
    ),
    // Graduated state layer: hover < focus < pressed.
    overlayColor: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.pressed)) {
        return stateLayer.withValues(alpha: 0.16);
      }
      if (s.contains(WidgetState.hovered)) {
        return stateLayer.withValues(alpha: 0.09);
      }
      if (s.contains(WidgetState.focused)) {
        return stateLayer.withValues(alpha: 0.12);
      }
      return null;
    }),
    side: side == null
        ? null
        : WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? side.copyWith(
                    color: side.color.withValues(alpha: disabledAlpha),
                  )
                : side,
          ),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashFactory: NoSplash.splashFactory,
    alignment: Alignment.center,
  );
}

/// Convenience accessor: `context.buttons`.
extension AppButtonThemeContext on BuildContext {
  AppButtonTheme get buttons => Theme.of(this).extension<AppButtonTheme>()!;
}

/// The button size scale. Each size fixes the height + horizontal padding and
/// picks a text style from the type ramp; the corner radius comes from the
/// user-adjustable `context.radii.component`.
enum AppButtonSize {
  /// 24pt — inline chips.
  xxSmall,

  /// 28pt.
  extraSmall,

  /// 32pt.
  small,

  /// 40pt — default.
  medium,

  /// 48pt.
  large,

  /// 54pt — hero CTAs.
  extraLarge;

  double get height => switch (this) {
    AppButtonSize.xxSmall => 24,
    AppButtonSize.extraSmall => 28,
    AppButtonSize.small => 32,
    AppButtonSize.medium => 40,
    AppButtonSize.large => 48,
    AppButtonSize.extraLarge => 54,
  };

  EdgeInsets get padding => switch (this) {
    AppButtonSize.xxSmall => const EdgeInsets.symmetric(horizontal: 10),
    AppButtonSize.extraSmall => const EdgeInsets.symmetric(horizontal: 12),
    AppButtonSize.small => const EdgeInsets.symmetric(horizontal: 12),
    AppButtonSize.medium => const EdgeInsets.symmetric(horizontal: 16),
    AppButtonSize.large => const EdgeInsets.symmetric(horizontal: 20),
    AppButtonSize.extraLarge => const EdgeInsets.symmetric(horizontal: 24),
  };

  Size get minimumSize => Size(0, height);

  TextStyle textStyle(BuildContext context) {
    final t = context.typography;
    final base = switch (this) {
      AppButtonSize.xxSmall || AppButtonSize.extraSmall => t.captionStrong,
      AppButtonSize.small => t.bodySmStrong,
      AppButtonSize.medium => t.bodyStrong,
      AppButtonSize.large => t.subtitle,
      AppButtonSize.extraLarge => t.titleSm,
    };
    return base.copyWith(height: 1.1, fontWeight: FontWeight.w600);
  }
}

/// The button's visual identity. Resolves to a [ButtonStyle] from
/// [AppButtonTheme] (`context.buttons`).
enum AppButtonVariant {
  filled,
  filledNeutral,
  outlined,
  outlinedNeutral,
  text,
  textNeutral,
  error;

  ButtonStyle style(BuildContext context) {
    final b = context.buttons;
    return switch (this) {
      AppButtonVariant.filled => b.filled,
      AppButtonVariant.filledNeutral => b.filledNeutral,
      AppButtonVariant.outlined => b.outlined,
      AppButtonVariant.outlinedNeutral => b.outlinedNeutral,
      AppButtonVariant.text => b.text,
      AppButtonVariant.textNeutral => b.textNeutral,
      AppButtonVariant.error => b.error,
    };
  }
}

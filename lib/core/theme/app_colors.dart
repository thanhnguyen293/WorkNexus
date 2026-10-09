import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Semantic **color** tokens exposed to the widget tree via [ThemeExtension].
///
/// Roles are named by function (`background`, `surface`, `success`, …) rather
/// than by hue, so call sites read intent, not implementation. Read it with the
/// `context.colors` getter.
/// "Verified" check colours by seniority (see [AppColors.verifiedLead]):
/// the familiar social-app blue, then violet, then gold at the top.
const Color kVerifiedLead = Color(0xFF1D9BF0);
const Color kVerifiedManager = Color(0xFF8B5CF6);
const Color kVerifiedExecutive = Color(0xFFF5B400);

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.card,
    required this.titleBar,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.onAccent,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.selectionFill,
    required this.selectionBorder,
    required this.hoverFill,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.caution,
    required this.notice,
    required this.skeleton,
    required this.skeletonHighlight,
    required this.scrim,
    required this.onScrim,
    required this.onColorInk,
    required this.workspaceFallback,
    this.verifiedLead = kVerifiedLead,
    this.verifiedManager = kVerifiedManager,
    this.verifiedExecutive = kVerifiedExecutive,
  });

  /// Maps a raw [AppPalette] onto the semantic color roles.
  factory AppColors.fromPalette(AppPalette p) => AppColors(
    background: p.bg,
    surface: p.panel,
    surfaceSubtle: p.panel2,
    card: p.card,
    titleBar: p.titlebar,
    textPrimary: p.tx,
    textSecondary: p.tx2,
    textTertiary: p.tx3,
    onAccent: p.accentTx,
    border: p.line,
    borderStrong: p.line2,
    accent: p.accent,
    selectionFill: p.sel,
    selectionBorder: p.selLine,
    // Pointer-hover tint: the palette's ink at low alpha, so it darkens light
    // surfaces and lightens dark ones. Dark themes need a touch more to read.
    hoverFill: p.tx.withValues(
      alpha: p.brightness == Brightness.dark ? 0.08 : 0.06,
    ),
    success: p.green,
    warning: p.amber,
    error: p.red,
    info: p.violet,
    caution: p.orange,
    notice: p.yellow,
    skeleton: p.skel,
    skeletonHighlight: p.skel2,
    scrim: p.scrim,
    onScrim: p.onScrim,
    onColorInk: p.onColorInk,
    workspaceFallback: p.workspaceFallback,
  );

  // ---- Surfaces ----
  final Color background; // window background
  final Color surface; // sidebar / column background
  final Color surfaceSubtle; // insets, chips, inputs
  final Color card; // ticket card / elevated panel surface
  final Color titleBar; // custom window title bar

  // ---- Content ----
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color onAccent; // text/icon on an accent fill

  // ---- Lines ----
  final Color border; // hairline divider
  final Color borderStrong; // stronger border

  // ---- Interaction ----
  final Color accent; // brand accent
  final Color selectionFill; // selection background (accent, low alpha)
  final Color selectionBorder; // selection border (accent, mid alpha)
  final Color hoverFill; // pointer-hover tint over any surface (ink, low alpha)

  // ---- Feedback / status ----
  final Color success; // done / synced
  final Color warning; // warning / running agent
  final Color error; // urgent / blocked / error
  final Color info; // review
  final Color caution; // high / in-progress
  final Color notice; // medium

  // ---- Skeleton ----
  final Color skeleton; // skeleton base
  final Color skeletonHighlight; // skeleton shimmer highlight

  // ---- Utility ----
  final Color scrim; // modal / overlay scrim + shadow (black)
  final Color onScrim; // text/icons over a scrim
  final Color onColorInk; // near-black text/icon on a saturated colored fill
  final Color
  workspaceFallback; // neutral fallback when a workspace has no color

  /// The "verified" check beside a leading member's avatar, by seniority:
  /// project/product leads, department managers, senior management. The same
  /// in every theme.
  final Color verifiedLead;
  final Color verifiedManager;
  final Color verifiedExecutive;

  // ---- color-mix helpers (see the design's CSS `color-mix`) ----

  /// `color-mix(in srgb, [c] pct%, transparent)` → [c] at [pct] alpha (0..1).
  Color mixT(Color c, double pct) => c.withValues(alpha: pct);

  /// `color-mix(in srgb, [c] pct%, [over])` with both opaque → sRGB lerp.
  Color mix(Color over, Color c, double pct) => Color.lerp(over, c, pct)!;

  /// Company-tint: [card] lightly tinted toward the workspace color.
  Color tintedCard(Color wsColor, {required bool enabled}) =>
      enabled ? Color.lerp(card, wsColor, 0.08)! : card;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? card,
    Color? titleBar,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? onAccent,
    Color? border,
    Color? borderStrong,
    Color? accent,
    Color? selectionFill,
    Color? selectionBorder,
    Color? hoverFill,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? caution,
    Color? notice,
    Color? skeleton,
    Color? skeletonHighlight,
    Color? scrim,
    Color? onScrim,
    Color? onColorInk,
    Color? workspaceFallback,
    Color? verifiedLead,
    Color? verifiedManager,
    Color? verifiedExecutive,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      card: card ?? this.card,
      titleBar: titleBar ?? this.titleBar,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      onAccent: onAccent ?? this.onAccent,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      accent: accent ?? this.accent,
      selectionFill: selectionFill ?? this.selectionFill,
      selectionBorder: selectionBorder ?? this.selectionBorder,
      hoverFill: hoverFill ?? this.hoverFill,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      caution: caution ?? this.caution,
      notice: notice ?? this.notice,
      skeleton: skeleton ?? this.skeleton,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      scrim: scrim ?? this.scrim,
      onScrim: onScrim ?? this.onScrim,
      onColorInk: onColorInk ?? this.onColorInk,
      workspaceFallback: workspaceFallback ?? this.workspaceFallback,
      verifiedLead: verifiedLead ?? this.verifiedLead,
      verifiedManager: verifiedManager ?? this.verifiedManager,
      verifiedExecutive: verifiedExecutive ?? this.verifiedExecutive,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceSubtle: c(surfaceSubtle, other.surfaceSubtle),
      card: c(card, other.card),
      titleBar: c(titleBar, other.titleBar),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      onAccent: c(onAccent, other.onAccent),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      accent: c(accent, other.accent),
      selectionFill: c(selectionFill, other.selectionFill),
      selectionBorder: c(selectionBorder, other.selectionBorder),
      hoverFill: c(hoverFill, other.hoverFill),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      error: c(error, other.error),
      info: c(info, other.info),
      caution: c(caution, other.caution),
      notice: c(notice, other.notice),
      skeleton: c(skeleton, other.skeleton),
      skeletonHighlight: c(skeletonHighlight, other.skeletonHighlight),
      scrim: c(scrim, other.scrim),
      onScrim: c(onScrim, other.onScrim),
      onColorInk: c(onColorInk, other.onColorInk),
      workspaceFallback: c(workspaceFallback, other.workspaceFallback),
      verifiedLead: c(verifiedLead, other.verifiedLead),
      verifiedManager: c(verifiedManager, other.verifiedManager),
      verifiedExecutive: c(verifiedExecutive, other.verifiedExecutive),
    );
  }
}

/// Convenience accessor: `context.colors`.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

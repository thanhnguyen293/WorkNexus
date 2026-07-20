import 'package:flutter/material.dart';

/// Which of the three editorial themes is active.
enum AppThemeVariant { light, dark, midnight }

/// Selectable app primary/accent colors offered in settings. `null` (not in this
/// list) means "use the theme variant's built-in accent". Two families — a
/// saturated row and a pastel row across the same hues — so the picker offers a
/// diverse spread. `onAccent` contrast is auto-chosen per color in the theme, so
/// light pastels get dark text.
const List<int> kAccentPresets = <int>[
  // Saturated
  0xFF5A57D6, // indigo
  0xFF2563EB, // blue
  0xFF0EA5E9, // sky
  0xFF0D9488, // teal
  0xFF16A34A, // green
  0xFFD97706, // amber
  0xFFEA580C, // orange
  0xFFE11D48, // rose
  0xFFDB2777, // pink
  0xFF7C3AED, // violet
  // Pastel
  0xFFA5B4FC, // pastel indigo
  0xFF93C5FD, // pastel blue
  0xFF7DD3FC, // pastel sky
  0xFF5EEAD4, // pastel teal
  0xFF86EFAC, // pastel green
  0xFFFCD34D, // pastel amber
  0xFFFDBA74, // pastel orange
  0xFFFDA4AF, // pastel rose
  0xFFF9A8D4, // pastel pink
  0xFFC4B5FD, // pastel violet
];

/// Flat vs outline surface treatment (outline adds 1px `line` borders).
enum SurfaceStyle { flat, outline }

/// Comfortable vs compact information density.
enum AppDensity { comfortable, compact }

/// The full set of semantic color tokens for one theme, ported verbatim from the
/// Claude Design "UnifiedTaskBoard Editorial" `renderVals()` palettes.
@immutable
class AppPalette {
  const AppPalette({
    required this.variant,
    required this.brightness,
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.card,
    required this.line,
    required this.line2,
    required this.tx,
    required this.tx2,
    required this.tx3,
    required this.accent,
    required this.accentTx,
    required this.titlebar,
    required this.sel,
    required this.selLine,
    required this.red,
    required this.orange,
    required this.yellow,
    required this.green,
    required this.amber,
    required this.violet,
    required this.skel,
    required this.skel2,
    required this.scrim,
    required this.onColorInk,
    required this.workspaceFallback,
  });

  final AppThemeVariant variant;
  final Brightness brightness;

  final Color bg; // window background
  final Color panel; // sidebar / column background
  final Color panel2; // insets, chips, inputs
  final Color card; // ticket card surface
  final Color line; // hairline divider
  final Color line2; // stronger border
  final Color tx; // primary text
  final Color tx2; // secondary text
  final Color tx3; // tertiary / muted text
  final Color accent; // brand accent
  final Color accentTx; // text on accent
  final Color titlebar; // custom window title bar
  final Color sel; // selection fill (accent, low alpha)
  final Color selLine; // selection border (accent, mid alpha)
  final Color red; // urgent / blocked / error
  final Color orange; // high / in-progress
  final Color yellow; // medium
  final Color green; // done / synced / success
  final Color amber; // warning / running agent
  final Color violet; // review
  final Color skel; // skeleton base
  final Color skel2; // skeleton shimmer highlight
  final Color scrim; // modal / overlay scrim + shadow (black)
  final Color onColorInk; // near-black text/icon on a saturated colored fill
  final Color
  workspaceFallback; // neutral fallback when a workspace has no color

  // Neutral (cool-leaning) light palette — replaces the old warm "editorial"
  // cream, which read as a yellow cast. Surfaces step bg -> panel -> card with a
  // wide enough gap that white cards separate on the flat surface (no borders).
  static const light = AppPalette(
    variant: AppThemeVariant.light,
    brightness: Brightness.light,
    bg: Color(0xFFE8E9EE), // board/window canvas — grey so white cards pop
    panel: Color(0xFFF7F8FA), // sidebar / column
    panel2: Color(0xFFE9EBEF), // insets, chips, inputs
    card: Color(0xFFFFFFFF), // ticket card
    line: Color(0xFFDCDFE6),
    line2: Color(0xFFC4C9D2),
    tx: Color(0xFF1C1F26), // neutral near-black (no brown)
    tx2: Color(0xFF565D6B),
    tx3: Color(0xFF888E9B),
    accent: Color(0xFF5A57D6),
    accentTx: Color(0xFFFFFFFF),
    titlebar: Color(0xFFE3E5EB),
    sel: Color.fromRGBO(90, 87, 214, .10),
    selLine: Color.fromRGBO(90, 87, 214, .5),
    red: Color(0xFFDC2626),
    orange: Color(0xFFC56A12),
    yellow: Color(0xFFA67C10),
    green: Color(0xFF2F8A52),
    amber: Color(0xFFB1740E),
    violet: Color(0xFF7C53C8),
    skel: Color.fromRGBO(0, 0, 0, .05),
    skel2: Color.fromRGBO(0, 0, 0, .09),
    scrim: Color(0xFF000000),
    onColorInk: Color(0xFF0B0D11),
    workspaceFallback: Color(0xFF888888),
  );

  static const dark = AppPalette(
    variant: AppThemeVariant.dark,
    brightness: Brightness.dark,
    bg: Color(0xFF151515),
    panel: Color(0xFF1C1C1C),
    panel2: Color(0xFF242424),
    card: Color(0xFF252525), // lighter than bg so flat cards separate
    line: Color(0xFF323232),
    line2: Color(0xFF3D3D3D),
    tx: Color(0xFFEDEDED),
    tx2: Color(0xFFA5A5A5),
    tx3: Color(0xFF707070),
    accent: Color(0xFF7F83F0),
    accentTx: Color(0xFFFFFFFF),
    titlebar: Color(0xFF191919),
    sel: Color.fromRGBO(127, 131, 240, .18),
    selLine: Color.fromRGBO(127, 131, 240, .5),
    red: Color(0xFFEF6B63),
    orange: Color(0xFFE59A4A),
    yellow: Color(0xFFD8B850),
    green: Color(0xFF4CC06B),
    amber: Color(0xFFE3A63C),
    violet: Color(0xFF9D8CFF),
    skel: Color.fromRGBO(255, 255, 255, .05),
    skel2: Color.fromRGBO(255, 255, 255, .10),
    scrim: Color(0xFF000000),
    onColorInk: Color(0xFF0B0D11),
    workspaceFallback: Color(0xFF888888),
  );

  // Ported verbatim from the BugPanel design's midnight CSS vars.
  static const midnight = AppPalette(
    variant: AppThemeVariant.midnight,
    brightness: Brightness.dark,
    bg: Color(0xFF0C0E13),
    panel: Color(0xFF12151D),
    panel2: Color(0xFF181C26),
    card: Color(0xFF1C222E), // lighter than panel2/bg so flat cards separate
    line: Color(0xFF2A303D),
    line2: Color(0xFF38404F),
    tx: Color(0xFFE9ECF3),
    tx2: Color(0xFF9AA4B8),
    tx3: Color(0xFF697386),
    accent: Color(0xFF6A86FF),
    accentTx: Color(0xFFFFFFFF),
    titlebar: Color(0xFF090B10),
    sel: Color.fromRGBO(106, 134, 255, .15),
    selLine: Color.fromRGBO(106, 134, 255, .5),
    red: Color(0xFFEF6B63),
    orange: Color(0xFFE59A4A),
    yellow: Color(0xFFD8B850),
    green: Color(0xFF4CC06B),
    amber: Color(0xFFE3A63C),
    violet: Color(0xFF9D8CFF),
    skel: Color.fromRGBO(255, 255, 255, .055),
    skel2: Color.fromRGBO(255, 255, 255, .11),
    scrim: Color(0xFF000000),
    onColorInk: Color(0xFF0B0D11),
    workspaceFallback: Color(0xFF888888),
  );

  static AppPalette of(AppThemeVariant v) => switch (v) {
    AppThemeVariant.light => light,
    AppThemeVariant.dark => dark,
    AppThemeVariant.midnight => midnight,
  };
}

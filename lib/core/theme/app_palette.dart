import 'package:flutter/material.dart';

/// Which of the three editorial themes is active.
enum AppThemeVariant { light, dark, midnight }

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

  static const light = AppPalette(
    variant: AppThemeVariant.light,
    brightness: Brightness.light,
    bg: Color(0xFFF4F1EA),
    panel: Color(0xFFFBFAF6),
    panel2: Color(0xFFEFEADF),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE6DFD1),
    line2: Color(0xFFD6CBB6),
    tx: Color(0xFF282219),
    tx2: Color(0xFF6F675A),
    tx3: Color(0xFF9D9484),
    accent: Color(0xFF5A57D6),
    accentTx: Color(0xFFFFFFFF),
    titlebar: Color(0xFFEEE7DB),
    sel: Color.fromRGBO(90, 87, 214, .10),
    selLine: Color.fromRGBO(90, 87, 214, .5),
    red: Color(0xFFCF432C),
    orange: Color(0xFFC56A12),
    yellow: Color(0xFFA67C10),
    green: Color(0xFF2F8A52),
    amber: Color(0xFFB1740E),
    violet: Color(0xFF7C53C8),
    skel: Color.fromRGBO(0, 0, 0, .045),
    skel2: Color.fromRGBO(0, 0, 0, .085),
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
    card: Color(0xFF1F1F1F),
    line: Color(0xFF2E2E2E),
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

  static const midnight = AppPalette(
    variant: AppThemeVariant.midnight,
    brightness: Brightness.dark,
    bg: Color(0xFF0A0C18),
    panel: Color(0xFF111428),
    panel2: Color(0xFF171B33),
    card: Color(0xFF171B33),
    line: Color(0xFF272D4A),
    line2: Color(0xFF3A4166),
    tx: Color(0xFFEAECF8),
    tx2: Color(0xFF9BA2C6),
    tx3: Color(0xFF6D7399),
    accent: Color(0xFF4D94FF),
    accentTx: Color(0xFFFFFFFF),
    titlebar: Color(0xFF0B0D1A),
    sel: Color.fromRGBO(77, 148, 255, .17),
    selLine: Color.fromRGBO(77, 148, 255, .6),
    red: Color(0xFFF56B74),
    orange: Color(0xFFF0A05A),
    yellow: Color(0xFFE6C15A),
    green: Color(0xFF4FC79B),
    amber: Color(0xFFEAB54E),
    violet: Color(0xFFB39DFF),
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

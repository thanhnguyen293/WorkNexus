import 'package:flutter/material.dart';

/// **Dimension** tokens exposed to the widget tree via [ThemeExtension]: icon
/// sizes, control heights and container widths.
///
/// Spacing tokens are gaps; these are the sizes of things. Reach for them
/// instead of literal pixel values or `spacing.xl6 * k` arithmetic. The scale
/// is identical across theme variants, so [lerp]/[copyWith] are no-ops. Read
/// it with the `context.sizes` getter.
@immutable
class AppSizes extends ThemeExtension<AppSizes> {
  const AppSizes();

  // ---- Icons (Lucide, weight 300) ----
  double get iconXs => 12; // inline with captions, chip affordances
  double get iconSm => 14; // inside dense rows, inputs, chips
  double get iconMd => 16; // toolbar / icon buttons, menu entries
  double get iconLg => 20; // rail, prominent header actions
  double get iconXl => 24; // empty / error state glyphs

  // ---- Controls (desktop pointer targets) ----
  double get controlSm =>
      28; // icon buttons, chips, sidebar rows — minimum target
  double get controlMd => 32; // toolbar controls, inputs, tabs
  double get controlLg => 36; // primary page actions
  double get stateTile => 48; // the icon tile above an empty / error message

  // ---- Containers ----
  double get dialogSm => 400; // confirms, single-field prompts
  double get dialogMd => 480; // forms
  double get dialogLg => 640; // rich content (release notes, profiles)
  double get sidePanel => 400; // slide-over panels (notifications, threads)
  double get boardColumn => 272; // one kanban column
  double get stateMessage => 360; // max line length of an empty / error message

  // ---- Shell layout (unified workspace shell) ----
  double get railWidth => 76;
  double get toolPaneWidth => 300;
  double get titleBarHeight => 56;

  /// The title bar on macOS; the traffic lights are centred in it by
  /// macos/Runner/MainFlutterWindow.swift, which has the same height.
  double get macTitleBarHeight => 52;
  double get detailPanelWidth => 460;
  double get railButton => 32;
  Size get switcherPopover => const Size(360, 440);
  double get switcherPopoverWidth => 360;
  double get switcherPopoverHeight => 440;

  @override
  AppSizes copyWith() => const AppSizes();

  @override
  AppSizes lerp(covariant AppSizes? other, double t) => other ?? this;
}

/// Convenience accessor: `context.sizes`.
extension AppSizesContext on BuildContext {
  AppSizes get sizes => Theme.of(this).extension<AppSizes>()!;
}

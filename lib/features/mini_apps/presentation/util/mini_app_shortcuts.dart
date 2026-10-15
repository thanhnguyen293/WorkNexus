import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The browser's usual keys for a mini app, to hand to [CallbackShortcuts].
/// Ctrl and Cmd are interchangeable so the same keys work on Windows and
/// macOS. Esc is left to the page, which often uses it.
Map<ShortcutActivator, VoidCallback> miniAppShortcuts({
  required VoidCallback reload,
  required VoidCallback hardReload,
  required VoidCallback back,
  required VoidCallback forward,
  required VoidCallback focusAddress,
  required VoidCallback devTools,
}) => {
  for (final ctrl in const [true, false]) ...{
    SingleActivator(LogicalKeyboardKey.keyR, control: ctrl, meta: !ctrl):
        reload,
    SingleActivator(
      LogicalKeyboardKey.keyR,
      control: ctrl,
      meta: !ctrl,
      shift: true,
    ): hardReload,
    SingleActivator(LogicalKeyboardKey.keyL, control: ctrl, meta: !ctrl):
        focusAddress,
    SingleActivator(
      LogicalKeyboardKey.keyI,
      control: ctrl,
      meta: !ctrl,
      shift: true,
    ): devTools,
  },
  const SingleActivator(LogicalKeyboardKey.f5): reload,
  const SingleActivator(LogicalKeyboardKey.f5, control: true): hardReload,
  const SingleActivator(LogicalKeyboardKey.f6): focusAddress,
  const SingleActivator(LogicalKeyboardKey.f12): devTools,
  const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): back,
  const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): forward,
};

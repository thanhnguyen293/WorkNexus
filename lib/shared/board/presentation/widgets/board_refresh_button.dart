import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';

/// The board toolbar's manual Refresh: fetches the board on screen again from
/// its provider. Each tool says what that means for its board ([onPressed])
/// and whether it is fetching now ([loading]); while it is, a spinner stands
/// in and taps are ignored. ⌘R (macOS) / Ctrl+R elsewhere presses it, as the
/// tooltip says.
class BoardRefreshButton extends StatefulWidget {
  const BoardRefreshButton({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  State<BoardRefreshButton> createState() => _BoardRefreshButtonState();
}

class _BoardRefreshButtonState extends State<BoardRefreshButton> {
  static bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyR) {
      return false;
    }
    // Boards the viewport keeps mounted off screen (and under a mini app,
    // which has its own ⌘R) hold a button too: only the one on screen acts.
    if (!mounted || !TickerMode.valuesOf(context).enabled) return false;
    final keys = HardwareKeyboard.instance;
    final modifier = _isMac ? keys.isMetaPressed : keys.isControlPressed;
    final other = _isMac ? keys.isControlPressed : keys.isMetaPressed;
    if (!modifier || other || keys.isShiftPressed || keys.isAltPressed) {
      return false;
    }
    if (!widget.loading) widget.onPressed();
    return true;
  }

  @override
  Widget build(BuildContext context) => AppIconButton(
    icon: LucideIcons.rotateCw300,
    tooltip: AppL10n.of(context).refreshWithShortcut(_isMac ? '⌘R' : 'Ctrl+R'),
    isLoading: widget.loading,
    onPressed: widget.onPressed,
  );
}

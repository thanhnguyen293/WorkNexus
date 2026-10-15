import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Minimize, maximize/restore (zoom), and close buttons for Linux and Windows.
class DesktopWindowButtons extends StatefulWidget {
  const DesktopWindowButtons({super.key});

  @override
  State<DesktopWindowButtons> createState() => _DesktopWindowButtonsState();
}

class _DesktopWindowButtonsState extends State<DesktopWindowButtons>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_checkMaximized());
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = maximized);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return SizedBox(
      height: 34,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WindowCaptionButton.minimize(
            brightness: brightness,
            onPressed: () async {
              if (await windowManager.isMinimized()) {
                await windowManager.restore();
              } else {
                await windowManager.minimize();
              }
            },
          ),
          if (_isMaximized)
            WindowCaptionButton.unmaximize(
              brightness: brightness,
              onPressed: windowManager.unmaximize,
            )
          else
            WindowCaptionButton.maximize(
              brightness: brightness,
              onPressed: windowManager.maximize,
            ),
          WindowCaptionButton.close(
            brightness: brightness,
            onPressed: windowManager.close,
          ),
        ],
      ),
    );
  }
}

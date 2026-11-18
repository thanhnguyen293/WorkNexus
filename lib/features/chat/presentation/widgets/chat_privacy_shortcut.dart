import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_privacy_providers.dart';

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// The privacy mode's shortcut as shown to the user.
String get chatPrivacyShortcutLabel => _isMac ? '⌘⇧H' : 'Ctrl+Shift+H';

/// Turns the chat privacy mode on or off on ⌘⇧H / Ctrl+Shift+H, wherever
/// focus is (or when nothing has it), so it is at hand the moment a screen
/// is shared. Takes no room: mount it once anywhere in the app shell.
class ChatPrivacyShortcut extends ConsumerStatefulWidget {
  const ChatPrivacyShortcut({super.key});

  @override
  ConsumerState<ChatPrivacyShortcut> createState() =>
      _ChatPrivacyShortcutState();
}

class _ChatPrivacyShortcutState extends ConsumerState<ChatPrivacyShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyH) {
      return false;
    }
    final keys = HardwareKeyboard.instance;
    final command = _isMac ? keys.isMetaPressed : keys.isControlPressed;
    if (!command || !keys.isShiftPressed || keys.isAltPressed) return false;
    toggleChatPrivacyMode(ref);
    return true;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

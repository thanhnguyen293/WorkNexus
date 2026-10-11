import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The editor's keys: Esc does what Cancel does, ⌘S / Ctrl+S what Save does
/// (nothing while [onSave] is null).
class EditorShortcuts extends StatelessWidget {
  const EditorShortcuts({
    super.key,
    required this.onClose,
    required this.onSave,
    required this.child,
  });

  final VoidCallback onClose;
  final VoidCallback? onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    void save() => onSave?.call();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onClose,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): save,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): save,
      },
      // Holds focus when no field does, so the keys work straight away.
      child: Focus(autofocus: true, child: child),
    );
  }
}

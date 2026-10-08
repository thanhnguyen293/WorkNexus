import 'package:flutter/material.dart';

import '../../../../core/widgets/app_context_menu.dart';
import 'message_hover_actions.dart';

/// Opens the action menu of a message at [at] (global) and runs the picked
/// action once the menu is gone. Used for right-click and the hover "…".
/// Reply stands apart from the rest; destructive actions (retract) come last.
Future<void> showMessageContextMenu(
  BuildContext context, {
  required List<MessageAction> actions,
  required Offset at,
}) async {
  if (actions.isEmpty) return;
  final firstDestructive = actions.indexWhere((a) => a.destructive);
  final picked = await showAppContextMenu(
    context,
    at: at,
    entries: [
      for (final (i, a) in actions.indexed)
        AppMenuEntry(
          icon: a.icon,
          label: a.tooltip,
          destructive: a.destructive,
          dividerBefore: i == 1 || i == firstDestructive,
        ),
    ],
  );
  if (picked != null) actions[picked].onTap();
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import 'app_context_menu.dart';

/// An image's right-click menu at [at] (global): copy it, and — given
/// [onOpenExternally] — open it in the browser. Runs the picked action.
Future<void> showImageContextMenu(
  BuildContext context, {
  required Offset at,
  required VoidCallback onCopy,
  VoidCallback? onOpenExternally,
}) async {
  final l = AppL10n.of(context);
  final actions = [
    (LucideIcons.copy300, l.copyImage, onCopy),
    if (onOpenExternally != null)
      (
        LucideIcons.squareArrowOutUpRight300,
        l.openImageInBrowser,
        onOpenExternally,
      ),
  ];
  final picked = await showAppContextMenu(
    context,
    at: at,
    entries: [
      for (final (icon, label, _) in actions)
        AppMenuEntry(icon: icon, label: label),
    ],
  );
  if (picked != null) actions[picked].$3();
}

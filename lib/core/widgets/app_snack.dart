import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import 'app_toast_controller.dart';
import 'app_toast_host.dart';

export 'app_toast_controller.dart' show AppToastKind;

/// Shows the app's toast: a compact card at the top centre (see
/// [AppToastLayer]) that never covers the inputs along the bottom. [kind]
/// says what it reports; [isError] is the shorthand for an error, so a
/// failure doesn't read like a confirmation. Safe to call after an `await`:
/// it checks `context.mounted`.
void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  AppToastKind? kind,
}) {
  if (!context.mounted) return;
  final k = _kindOf(kind, isError);
  final toasts = AppToasts.maybeOf(context);
  if (toasts != null) return toasts.show(message, kind: k);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) _showSnackBar(messenger, message, kind: k);
}

/// [showAppSnack] on a messenger captured before an `await`, for callers
/// whose own context may be gone by the time the result arrives (a dialog
/// that closes itself, a form rebuilt mid-save).
void showAppSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  bool isError = false,
  AppToastKind? kind,
}) {
  if (!messenger.mounted) return;
  final k = _kindOf(kind, isError);
  final toasts = AppToasts.maybeOf(messenger.context);
  if (toasts != null) return toasts.show(message, kind: k);
  _showSnackBar(messenger, message, kind: k);
}

AppToastKind _kindOf(AppToastKind? kind, bool isError) =>
    kind ?? (isError ? AppToastKind.error : AppToastKind.success);

/// Outside an [AppToasts] (a widget test's bare `MaterialApp`), the plain
/// floating snack bar.
void _showSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  required AppToastKind kind,
}) {
  final context = messenger.context;
  final c = context.colors;
  final ink = Theme.of(context).snackBarTheme.contentTextStyle?.color;
  final (glyph, color) = switch (kind) {
    AppToastKind.success => (LucideIcons.circleCheck300, ink),
    AppToastKind.warning => (LucideIcons.triangleAlert300, c.warning),
    AppToastKind.error => (LucideIcons.circleAlert300, c.error),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(glyph, size: context.sizes.iconMd, color: color),
            SizedBox(width: context.spacing.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

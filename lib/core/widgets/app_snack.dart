import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import 'app_toast_host.dart';

/// Shows the app's toast: a compact pill at the top centre (see
/// [AppToastLayer]) that never covers the inputs along the bottom. [isError]
/// leads with an alert glyph so a failure doesn't read like a confirmation.
/// Safe to call after an `await`: it checks `context.mounted`.
void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  final toasts = AppToasts.maybeOf(context);
  if (toasts != null) return toasts.show(message, isError: isError);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) _showSnackBar(messenger, message, isError: isError);
}

/// [showAppSnack] on a messenger captured before an `await`, for callers
/// whose own context may be gone by the time the result arrives (a dialog
/// that closes itself, a form rebuilt mid-save).
void showAppSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  bool isError = false,
}) {
  if (!messenger.mounted) return;
  final toasts = AppToasts.maybeOf(messenger.context);
  if (toasts != null) return toasts.show(message, isError: isError);
  _showSnackBar(messenger, message, isError: isError);
}

/// Outside an [AppToasts] (a widget test's bare `MaterialApp`), the plain
/// floating snack bar.
void _showSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  required bool isError,
}) {
  final context = messenger.context;
  final ink = Theme.of(context).snackBarTheme.contentTextStyle?.color;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.circleAlert300 : LucideIcons.circleCheck300,
              size: context.sizes.iconMd,
              color: isError ? context.colors.error : ink,
            ),
            SizedBox(width: context.spacing.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

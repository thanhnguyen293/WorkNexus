import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';

/// Shows the app's floating toast (styled by the theme's `snackBarTheme`).
/// [isError] leads with an alert glyph so a failure doesn't read like a
/// confirmation. Safe to call after an `await`: it checks `context.mounted`.
void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  SnackBarAction? action,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  showAppSnackOn(messenger, message, isError: isError, action: action);
}

/// [showAppSnack] on a messenger captured before an `await`, for callers
/// whose own context may be gone by the time the result arrives (a dialog
/// that closes itself, a form rebuilt mid-save).
void showAppSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  bool isError = false,
  SnackBarAction? action,
}) {
  if (!messenger.mounted) return;
  final context = messenger.context;
  final ink = Theme.of(context).snackBarTheme.contentTextStyle?.color;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        action: action,
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

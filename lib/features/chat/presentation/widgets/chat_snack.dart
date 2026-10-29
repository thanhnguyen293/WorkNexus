import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';

/// Reports a failed chat command next to where it happened.
void showChatFailure(
  BuildContext context,
  Failure failure, {
  VoidCallback? onReconnect,
}) {
  if (!context.mounted) return;
  final l = AppL10n.of(context);
  if (failure is ExpiredFailure) {
    showAppSnack(context, l.chatReactionRemoveExpired);
    return;
  }
  showAppSnack(context, l.chatActionFailed(failure.message), isError: true);
}

/// A short confirmation (copied, saved, …).
void showChatSnack(BuildContext context, String message) =>
    showAppSnack(context, message);

import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';

/// Reports a failed chat command next to where it happened.
void showChatFailure(BuildContext context, Failure failure) {
  if (!context.mounted) return;
  if (failure is ExpiredFailure) {
    showAppSnack(
      context,
      AppL10n.of(context).chatReactionRemoveExpired,
      kind: AppToastKind.warning,
    );
    return;
  }
  showAppSnack(
    context,
    AppL10n.of(context).chatActionFailed(failure.message),
    isError: true,
  );
}

/// A short note on a chat action: a confirmation (copied, saved, …) unless
/// [kind] says otherwise.
void showChatSnack(
  BuildContext context,
  String message, {
  AppToastKind kind = AppToastKind.success,
}) => showAppSnack(context, message, kind: kind);

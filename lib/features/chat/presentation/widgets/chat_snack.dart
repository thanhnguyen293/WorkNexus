import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';

/// Reports a failed chat command next to where it happened.
void showChatFailure(BuildContext context, Failure failure) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppL10n.of(context).chatActionFailed(failure.message)),
    ),
  );
}

import 'package:flutter/widgets.dart';

import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';

/// Asks whether to delete the draft being written.
Future<bool> confirmDiscardDraft(BuildContext context) {
  final l = AppL10n.of(context);
  return AppConfirmDialog.show(
    context,
    title: l.ticketDraftDiscardTitle,
    message: l.ticketDraftDiscardMessage,
    confirmLabel: l.ticketDraftDiscard,
    destructive: true,
  );
}

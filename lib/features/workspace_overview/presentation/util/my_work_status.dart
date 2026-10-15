import 'package:flutter/widgets.dart';

import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../l10n/app_localizations.dart';

/// ZenTao's own word for where a bug or task stands. The unified status
/// already encodes it (a confirmed bug is `todo`, a paused task `blocked`),
/// so rows, section headers and pills all read the same.
String myWorkStatusLabel(AppL10n l, UnifiedStatus status, {required bool bug}) {
  if (bug) {
    return switch (status) {
      UnifiedStatus.inbox => l.myWorkStatusUnconfirmed,
      UnifiedStatus.review => l.myWorkStatusResolved,
      UnifiedStatus.done => l.myWorkStatusClosed,
      _ => l.myWorkStatusConfirmed,
    };
  }
  return switch (status) {
    UnifiedStatus.inprogress => l.myWorkStatusDoing,
    UnifiedStatus.blocked => l.myWorkStatusPaused,
    UnifiedStatus.review => l.myWorkStatusDone,
    UnifiedStatus.done => l.myWorkStatusClosed,
    _ => l.myWorkStatusWaiting,
  };
}

/// The status color used across the dashboard — the board's column dots.
Color myWorkStatusColor(AppColors c, UnifiedStatus status) =>
    statusColor(c, status);

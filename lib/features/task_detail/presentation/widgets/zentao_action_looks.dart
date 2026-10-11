import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_bug_action.dart';
import '../../domain/value_objects/zentao_create_action.dart';

/// How a ZenTao action shows: its name and button icon.
typedef ZenTaoActionLook = ({String label, IconData icon});

ZenTaoActionLook zenTaoBugActionLook(AppL10n l, ZenTaoBugAction action) =>
    switch (action) {
      ZenTaoBugAction.confirm => (
        label: l.zentaoConfirm,
        icon: LucideIcons.badgeCheck300,
      ),
      ZenTaoBugAction.resolve => (
        label: l.resolve,
        icon: LucideIcons.checkCircle300,
      ),
      ZenTaoBugAction.close => (label: l.close, icon: LucideIcons.archive300),
      ZenTaoBugAction.activate => (
        label: l.activate,
        icon: LucideIcons.rotateCcw300,
      ),
    };

ZenTaoActionLook zenTaoTaskActionLook(
  AppL10n l,
  ZenTaoTaskAction action,
) => switch (action) {
  ZenTaoTaskAction.start => (label: l.zentaoStart, icon: LucideIcons.play300),
  ZenTaoTaskAction.restart => (
    label: l.zentaoRestart,
    icon: LucideIcons.playCircle300,
  ),
  ZenTaoTaskAction.pause => (label: l.zentaoPause, icon: LucideIcons.pause300),
  ZenTaoTaskAction.finish => (label: l.zentaoFinish, icon: LucideIcons.flag300),
  ZenTaoTaskAction.activate => (
    label: l.activate,
    icon: LucideIcons.rotateCcw300,
  ),
  ZenTaoTaskAction.close => (label: l.close, icon: LucideIcons.archive300),
  ZenTaoTaskAction.cancel => (
    label: l.zentaoCancelTask,
    icon: LucideIcons.ban300,
  ),
};

/// How starting something new from a bug or task shows: its name and icon.
({String label, IconData icon}) zenTaoCreateActionLook(
  AppL10n l,
  ZenTaoCreateAction action,
) => switch (action) {
  ZenTaoCreateAction.copyBug => (
    label: l.zentaoCopyBug,
    icon: LucideIcons.copy300,
  ),
  ZenTaoCreateAction.subtask => (
    label: l.zentaoAddSubtask,
    icon: LucideIcons.network300,
  ),
  ZenTaoCreateAction.bugFromTask => (
    label: l.zentaoReportBug,
    icon: LucideIcons.bug300,
  ),
};

/// The snackbar line once [action] has run on ticket [key].
String zenTaoActionOutcome(
  AppL10n l,
  Result<void> result,
  String action,
  String key,
) => result.isOk
    ? l.zentaoActionDone(action, key)
    : l.actionFailed(result.failureOrNull?.message ?? '');

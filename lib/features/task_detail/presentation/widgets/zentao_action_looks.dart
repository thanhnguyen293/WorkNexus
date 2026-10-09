import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_bug_action.dart';
import '../../domain/value_objects/zentao_create_action.dart';

/// How a ZenTao action shows: its name, button icon and dialog emoji.
typedef ZenTaoActionLook = ({String label, IconData icon, String emoji});

ZenTaoActionLook zenTaoBugActionLook(AppL10n l, ZenTaoBugAction action) =>
    switch (action) {
      ZenTaoBugAction.confirm => (
        label: l.zentaoConfirm,
        icon: PhosphorIconsLight.sealCheck,
        emoji: '🔎',
      ),
      ZenTaoBugAction.resolve => (
        label: l.resolve,
        icon: PhosphorIconsLight.checkCircle,
        emoji: '✅',
      ),
      ZenTaoBugAction.close => (
        label: l.close,
        icon: PhosphorIconsLight.archive,
        emoji: '🔒',
      ),
      ZenTaoBugAction.activate => (
        label: l.activate,
        icon: PhosphorIconsLight.arrowCounterClockwise,
        emoji: '🔁',
      ),
    };

ZenTaoActionLook zenTaoTaskActionLook(AppL10n l, ZenTaoTaskAction action) =>
    switch (action) {
      ZenTaoTaskAction.start => (
        label: l.zentaoStart,
        icon: PhosphorIconsLight.play,
        emoji: '▶️',
      ),
      ZenTaoTaskAction.restart => (
        label: l.zentaoRestart,
        icon: PhosphorIconsLight.playCircle,
        emoji: '⏯️',
      ),
      ZenTaoTaskAction.pause => (
        label: l.zentaoPause,
        icon: PhosphorIconsLight.pause,
        emoji: '⏸️',
      ),
      ZenTaoTaskAction.finish => (
        label: l.zentaoFinish,
        icon: PhosphorIconsLight.flagCheckered,
        emoji: '🏁',
      ),
      ZenTaoTaskAction.activate => (
        label: l.activate,
        icon: PhosphorIconsLight.arrowCounterClockwise,
        emoji: '🔁',
      ),
      ZenTaoTaskAction.close => (
        label: l.close,
        icon: PhosphorIconsLight.archive,
        emoji: '🔒',
      ),
      ZenTaoTaskAction.cancel => (
        label: l.zentaoCancelTask,
        icon: PhosphorIconsLight.prohibit,
        emoji: '🚫',
      ),
    };

/// How starting something new from a bug or task shows: its name and icon.
({String label, IconData icon}) zenTaoCreateActionLook(
  AppL10n l,
  ZenTaoCreateAction action,
) => switch (action) {
  ZenTaoCreateAction.copyBug => (
    label: l.zentaoCopyBug,
    icon: PhosphorIconsLight.copy,
  ),
  ZenTaoCreateAction.subtask => (
    label: l.zentaoAddSubtask,
    icon: PhosphorIconsLight.treeStructure,
  ),
  ZenTaoCreateAction.bugFromTask => (
    label: l.zentaoReportBug,
    icon: PhosphorIconsLight.bug,
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

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/check_zentao_task_input.dart';

/// Why a task form's input would be refused, under the fields it is about.
class TaskInputProblemText extends StatelessWidget {
  const TaskInputProblemText(this.problem, {super.key});

  final ZenTaoTaskInputProblem problem;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.md),
      child: Text(
        switch (problem) {
          ZenTaoTaskInputProblem.invalidHours => l.zentaoHoursInvalid,
          ZenTaoTaskInputProblem.leftRequired => l.zentaoHoursLeftRequired,
          ZenTaoTaskInputProblem.spentRequired => l.zentaoHoursSpentRequired,
          ZenTaoTaskInputProblem.endBeforeBegin => l.zentaoEndBeforeBegin,
        },
        style: context.typography.bodySm.copyWith(
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}

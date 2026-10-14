import 'package:flutter/material.dart';

import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import 'option_select.dart';

/// The bug's task. ZenTao lists tasks per execution, so until one is picked
/// the field asks for the execution instead: it lists the executions, and
/// picking one sets the bug's (which loads its tasks).
class BugTaskSelect extends StatelessWidget {
  const BugTaskSelect({
    super.key,
    required this.options,
    required this.execution,
    required this.task,
    required this.onExecution,
    required this.onTask,
  });

  final BugFormOptions options;
  final String execution;
  final String task;
  final ValueChanged<String> onExecution;
  final ValueChanged<String> onTask;

  @override
  Widget build(BuildContext context) {
    if (execution != '0') {
      return OptionSelect(
        options: options.tasks,
        value: task,
        noneValue: '0',
        onChanged: onTask,
      );
    }
    final l = AppL10n.of(context);
    return SearchableDropdownField<FormOption>(
      items: options.executions,
      value: null,
      labelOf: (o) => o.label,
      hintText: l.taskNeedsExecution,
      searchHint: l.searchExecutions,
      emptyLabel: l.noMatches,
      onChanged: (o) => onExecution(o.value),
      popoverMinWidth: context.sizes.dialogMd,
      labelMaxLines: 2,
    );
  }
}

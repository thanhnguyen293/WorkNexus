import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/domain/value_objects/zentao_task_column.dart';
import '../../../../shared/board/domain/usecases/derive_board_facets.dart';
import '../../../../shared/board/presentation/widgets/filter_option_group.dart';
import 'zentao_bug_column_parts.dart';
import 'zentao_task_column_parts.dart';

/// A status filter option, named and coloured like its board column (the
/// table's Status cell). [bugBoard] picks the bug columns over the task ones.
FilterChipOption Function(
  BuildContext context,
  BoardFacetOption option, {
  required bool active,
  required VoidCallback onTap,
})
zentaoStatusFilterOption({required bool bugBoard}) =>
    (context, option, {required active, required onTap}) {
      final bug = bugBoard
          ? ZenTaoBugColumn.values.asNameMap()[option.value]
          : null;
      final task = bugBoard
          ? null
          : ZenTaoTaskColumn.values.asNameMap()[option.value];
      final (label, color) = switch ((bug, task)) {
        (final bug?, _) => bugColumnVisual(context, bug),
        (_, final task?) => taskColumnVisual(context, task),
        _ => (option.value, null),
      };
      return FilterChipOption(
        label: label,
        count: option.count,
        active: active,
        dotColor: color,
        onTap: onTap,
      );
    };

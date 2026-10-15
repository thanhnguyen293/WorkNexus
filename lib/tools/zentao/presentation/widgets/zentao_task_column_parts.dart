import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/value_objects/zentao_task_column.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/board/presentation/widgets/paged_column_footer.dart';
import '../providers/zentao_task_streams.dart';

/// A ZenTao task column's label and status-dot colour.
(String, Color) taskColumnVisual(
  BuildContext context,
  ZenTaoTaskColumn column,
) {
  final c = context.colors;
  final l = AppL10n.of(context);
  return switch (column) {
    ZenTaoTaskColumn.notStarted => (l.boardTaskColNotStarted, c.textTertiary),
    ZenTaoTaskColumn.inProgress => (l.boardTaskColInProgress, c.accent),
    ZenTaoTaskColumn.paused => (l.boardTaskColPaused, c.warning),
    ZenTaoTaskColumn.doneVerify => (l.boardTaskColDoneVerify, c.success),
    ZenTaoTaskColumn.closed => (l.boardTaskColClosed, c.textSecondary),
    ZenTaoTaskColumn.canceled => (l.boardTaskColCanceled, c.error),
  };
}

/// The end of a task status view that has more pages — a board column's, or
/// the task table's: loads the view's next pages.
class ZenTaoTaskColumnFooter extends ConsumerWidget {
  const ZenTaoTaskColumnFooter({
    super.key,
    required this.column,
    required this.visible,
  });

  final ZenTaoTaskColumn column;

  /// How many of the view's tasks are shown.
  final int visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(zentaoTaskStreamsProvider.notifier);
    return PagedColumnFooter(
      stream: ref.watch(zentaoTaskColumnStreamProvider(column)),
      visible: visible,
      filtered: ref.watch(filterStateProvider.select((f) => f.narrowsTickets)),
      errorText: AppL10n.of(context).taskColumnLoadFailed,
      onLoadMore: () => controller.loadMore(column, visible: visible),
      onRetry: () => controller.retry(column),
    );
  }
}

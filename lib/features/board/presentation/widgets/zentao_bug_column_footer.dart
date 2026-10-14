import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_bug_column.dart';
import '../../domain/value_objects/zentao_bug_stream.dart';
import '../board_providers.dart';
import 'paged_column_footer.dart';

/// The end of a bug column whose view has more pages: loads the next pages of
/// the view [column] draws on.
class ZenTaoBugColumnFooter extends ConsumerWidget {
  const ZenTaoBugColumnFooter({super.key, required this.column});

  final ZenTaoBugColumn column;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(zentaoBugStreamsProvider.notifier);
    final view = ZenTaoBugStream.of(column);
    // One view feeds several columns (To close → Resolved, Postponed,
    // Non-fix): what it has turned up is the cards across all of them.
    final visible = ref.watch(
      zentaoBugBoardProvider.select(
        (board) => board.columns
            .where((c) => ZenTaoBugStream.of(c.column) == view)
            .fold(0, (sum, c) => sum + c.count),
      ),
    );
    return PagedColumnFooter(
      stream: ref.watch(zentaoBugColumnStreamProvider(column)),
      visible: visible,
      filtered: ref.watch(filterStateProvider.select((f) => f.narrowsTickets)),
      errorText: AppL10n.of(context).bugTabLoadFailed,
      onLoadMore: () => controller.loadMore(view, visible: visible),
      onRetry: () => controller.retry(view),
    );
  }
}

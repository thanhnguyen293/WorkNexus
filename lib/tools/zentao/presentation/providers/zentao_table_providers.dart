import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_task_column.dart';
import '../../../../shared/board/domain/usecases/build_paged_table.dart';
import '../../domain/value_objects/zentao_bug_stream.dart';
import 'zentao_board_providers.dart';
import 'zentao_bug_streams.dart';
import 'zentao_table_sort.dart';
import 'zentao_task_streams.dart';

/// The task board as one table: status by status, each status view's tasks
/// showing once the statuses before it are fully loaded.
final zentaoTaskTableProvider =
    Provider.autoDispose<PagedTable<ZenTaoTaskColumn>>((ref) {
      final board = ref.watch(zentaoTaskBoardProvider);
      final streams = ref.watch(zentaoTaskStreamsProvider);
      final hasExec = ref.watch(selectedZenTaoExecutionProvider) != null;
      return const BuildPagedTable<ZenTaoTaskColumn>()(
        PagedTableQuery(
          sort: ref.watch(zentaoTaskTableSortProvider),
          segments: [
            for (final col in board.columns)
              PagedTableSegment(
                view: col.column,
                tickets: col.tickets,
                complete: !hasExec || !(streams[col.column]?.hasMore ?? false),
              ),
          ],
        ),
      );
    });

/// The bug board as one table: view by view in column order (a view feeding
/// several columns — To close → Resolved, Postponed, Non-fix — is one stretch),
/// Closed only on the All tab, as on the board.
final zentaoBugTableProvider =
    Provider.autoDispose<PagedTable<ZenTaoBugStream>>((ref) {
      final board = ref.watch(zentaoBugBoardProvider);
      final streams = ref.watch(zentaoBugStreamsProvider);
      final mine = ref.watch(zentaoBugMineProvider);
      final byView = <ZenTaoBugStream, List<Ticket>>{};
      for (final col in board.columns) {
        byView
            .putIfAbsent(ZenTaoBugStream.of(col.column, mine: mine), () => [])
            .addAll(col.tickets);
      }
      return const BuildPagedTable<ZenTaoBugStream>()(
        PagedTableQuery(
          sort: ref.watch(zentaoBugTableSortProvider),
          segments: [
            for (final MapEntry(key: view, value: tickets) in byView.entries)
              PagedTableSegment(
                view: view,
                tickets: tickets,
                complete: !(streams[view]?.hasMore ?? false),
              ),
          ],
        ),
      );
    });

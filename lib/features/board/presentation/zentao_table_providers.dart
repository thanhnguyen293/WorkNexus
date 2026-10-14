import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/ticket.dart';
import '../domain/usecases/build_paged_table.dart';
import '../domain/value_objects/zentao_bug_stream.dart';
import '../domain/value_objects/zentao_task_column.dart';
import 'board_providers.dart';

/// The task board as one table: status by status, each status view's tasks
/// showing once the statuses before it are fully loaded.
final zentaoTaskTableProvider =
    Provider.autoDispose<PagedTable<ZenTaoTaskColumn>>((ref) {
      final board = ref.watch(zentaoTaskBoardProvider);
      final streams = ref.watch(zentaoTaskStreamsProvider);
      return const BuildPagedTable<ZenTaoTaskColumn>()(
        PagedTableQuery(
          sort: ref.watch(zentaoTaskTableSortProvider),
          segments: [
            for (final col in board.columns)
              PagedTableSegment(
                view: col.column,
                tickets: col.tickets,
                complete: !(streams[col.column]?.hasMore ?? false),
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
      final byView = <ZenTaoBugStream, List<Ticket>>{};
      for (final col in board.columns) {
        byView
            .putIfAbsent(ZenTaoBugStream.of(col.column), () => [])
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

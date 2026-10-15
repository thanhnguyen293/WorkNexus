import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../domain/usecases/list_task_bugs.dart';
import 'zentao_data_providers.dart';

/// The bugs related to ZenTao task [id] in the local database (see
/// [ListTaskBugs]); [taskBugsSyncProvider] brings the latest in.
final taskBugsProvider = Provider.autoDispose.family<List<Ticket>, String>((
  ref,
  id,
) {
  final task = ref.watch(ticketByIdProvider(id));
  if (task == null) return const [];
  return const ListTaskBugs()(
    task: task,
    tickets: ref.watch(ticketsProvider).asData?.value ?? const [],
  );
});

/// Stores task [id]'s related bugs as its detail opens (a recent read of its
/// execution's bugs may already hold them); the list updates through
/// [taskBugsProvider].
final taskBugsSyncProvider = FutureProvider.autoDispose
    .family<Result<void>, String>((ref, id) async {
      // Only where the task sits: it may arrive after the panel opens, and
      // the task's other changes need no new fetch.
      final scope = ref.watch(
        ticketByIdProvider(id).select(
          (task) => switch (task) {
            Ticket(
              :final accountId,
              :final externalKey,
              providerEntity: ZenTaoTaskEntity(:final execution?),
            ) =>
              (accountId: accountId, execution: execution, task: externalKey),
            _ => null,
          },
        ),
      );
      if (scope == null) return const Ok(null);
      return ref
          .read(zentaoTaskBugsProvider)
          .syncTaskBugs(
            accountId: scope.accountId,
            executionId: scope.execution,
            taskId: scope.task,
          );
    });

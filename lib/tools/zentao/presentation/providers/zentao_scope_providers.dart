import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/zentao_board_status.dart';
import '../../../../core/domain/value_objects/zentao_task_column.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/util/synthetic_labels.dart';
import '../../../../shared/board/domain/usecases/is_assigned_to_me.dart';
import '../../../../shared/board/domain/usecases/scope_paged_view_tickets.dart';
import '../../../../shared/board/domain/usecases/scope_provider_tickets.dart';
import '../../../../shared/board/domain/value_objects/paged_view_loads.dart';
import '../../domain/value_objects/zentao_bug_stream.dart';
import 'zentao_board_providers.dart';
import 'zentao_bug_streams.dart';
import 'zentao_task_streams.dart';

/// The ZenTao tickets the Tasks section shows before the user's filters: the
/// cached tasks tagged with the open execution, narrowed view by view to what
/// each status view has loaded — or filtered by the selected project scope.
List<Ticket> scopeZenTaoTasks(Ref ref, List<Ticket> tickets) {
  final execution = ref.watch(selectedZenTaoExecutionProvider);
  if (execution != null) {
    return const ScopePagedViewTickets<ZenTaoTaskColumn>()(
      PagedViewScopeQuery(
        tickets: const ScopeProviderTickets()(
          tickets: tickets,
          accountId: execution.accountId,
          providerType: ProviderType.zentao,
          externalType: 'task',
          membershipLabel: zentaoExecutionLabel(execution.executionId),
          slice: null,
        ),
        loads: PagedViewLoads.of(ref.watch(zentaoTaskStreamsProvider)),
        viewOf: zentaoTaskColumnFor,
      ),
    );
  }

  final nav = ref.watch(appNavProvider);
  final accountId = switch (nav.rail) {
    AccountTarget(:final accountId) => accountId,
    _ => null,
  };
  final scopeId = nav.currentLocation?.scopeId;

  if (scopeId != null && scopeId.isNotEmpty) {
    final execs = accountId != null
        ? ref
            .watch(
              zentaoExecutionsProvider((
                accountId: accountId,
                projectId: scopeId,
              )),
            )
            .asData
            ?.value
        : null;
    final childExecIds =
        execs?.map((e) => e.id).toSet() ?? const <String>{};

    return tickets.where((t) {
      if (accountId != null && t.accountId != accountId) return false;
      if (t.externalType?.toLowerCase() != 'task' &&
          t.providerEntity is! ZenTaoTaskEntity) {
        return false;
      }
      final task = t.providerEntity as ZenTaoTaskEntity?;
      if (t.projectId == scopeId ||
          t.projectId.endsWith(':$scopeId') ||
          task?.project == scopeId) {
        return true;
      }
      if (task?.execution != null && childExecIds.contains(task!.execution)) {
        return true;
      }
      for (final execId in childExecIds) {
        if (t.labels.contains(zentaoExecutionLabel(execId))) return true;
      }
      return false;
    }).toList();
  }

  if (accountId != null) {
    return tickets.where((t) {
      if (t.accountId != accountId) return false;
      return t.externalType?.toLowerCase() == 'task' ||
          t.providerEntity is ZenTaoTaskEntity;
    }).toList();
  }

  return tickets;
}

/// The ZenTao tickets the Bugs section shows before the user's filters: the
/// cached bugs tagged with the open product, narrowed view by view to what each
/// bug view has loaded. When a child execution is selected, filters strictly to that
/// execution; otherwise shows all bugs of the parent product.
List<Ticket> scopeZenTaoBugs(Ref ref, List<Ticket> tickets) {
  final product = ref.watch(selectedZenTaoProductProvider);
  if (product == null) return tickets;
  final execution = ref.watch(selectedZenTaoExecutionProvider);
  final mine = ref.watch(zentaoBugMineProvider);
  final streams = ref.watch(zentaoBugStreamsProvider);
  final account = ref.watch(
    lookupsProvider.select((l) => l.accounts[product.accountId]),
  );
  // Until Assigned to me's view loads, its cached bugs are those assigned to
  // the user locally; once it loads, the server's list decides.
  if (mine &&
      account != null &&
      !(streams[ZenTaoBugStream.assignedToMe]?.started ?? false)) {
    tickets = [
      for (final t in tickets)
        if (const IsAssignedToMe()(t, account)) t,
    ];
  }

  // Scope to bugs belonging to this product
  final prodId = product.productId;
  final prodName = product.productName;
  final prodLabel = zentaoProductLabel(prodId);

  tickets = tickets.where((t) {
    if (t.accountId != product.accountId) return false;
    if (t.externalType?.toLowerCase() != 'bug' &&
        t.providerEntity is! ZenTaoBugEntity) {
      return false;
    }
    if (t.labels.contains(prodLabel)) return true;
    if (t.providerEntity is ZenTaoBugEntity) {
      final b = t.providerEntity as ZenTaoBugEntity;
      if (b.product == prodId || b.productName == prodName) return true;
    }
    return false;
  }).toList();

  // When a child execution is selected, narrow bugs exclusively to that execution.
  // When no execution is selected (parent product only), all bugs for this product are included.
  if (execution != null) {
    final execId = execution.executionId;
    tickets = tickets.where((t) {
      if (t.providerEntity is ZenTaoBugEntity) {
        final b = t.providerEntity as ZenTaoBugEntity;
        if (b.execution == execId) return true;
      }
      return t.labels.contains(zentaoExecutionLabel(execId));
    }).toList();
  }

  return const ScopePagedViewTickets<ZenTaoBugStream>()(
    PagedViewScopeQuery(
      tickets: const ScopeProviderTickets()(
        tickets: tickets,
        accountId: product.accountId,
        providerType: ProviderType.zentao,
        externalType: 'bug',
        slice: null,
      ),
      loads: PagedViewLoads.of(streams),
      viewOf: (t) => ZenTaoBugStream.of(zentaoBugColumnFor(t), mine: mine),
    ),
  );
}

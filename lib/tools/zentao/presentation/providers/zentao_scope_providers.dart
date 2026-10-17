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

/// Whether [t] is a task of ZenTao project [projectId] (its numeric id), for
/// the open-task counts on project rows — information only: a project is
/// never a task board.
bool zentaoTaskInProject(Ticket t, String projectId) =>
    switch (t.providerEntity) {
      ZenTaoTaskEntity(:final project) => project == projectId,
      _ => false,
    };

/// The rail's account and the open scope. The product / execution selections
/// are app-wide, so they apply only while they match this place: another
/// account, or a scope reset to "All", must not keep showing them.
({String? accountId, String? scopeId}) _place(Ref ref) {
  final nav = ref.watch(appNavProvider);
  return (
    accountId: switch (nav.rail) {
      AccountTarget(:final accountId) => accountId,
      _ => null,
    },
    scopeId: nav.currentLocation?.scopeId,
  );
}

List<Ticket> scopeZenTaoTasks(Ref ref, List<Ticket> tickets) {
  final place = _place(ref);
  final selected = ref.watch(selectedZenTaoExecutionProvider);
  final execution =
      selected != null &&
          selected.accountId == place.accountId &&
          selected.executionId == place.scopeId
      ? selected
      : null;
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

  // Tasks are listed per execution: until this board's is picked (the
  // section picks one) there are none to show.
  return const [];
}

/// The ZenTao tickets the Bugs section shows before the user's filters: the
/// cached bugs tagged with the open product, narrowed view by view to what each
/// bug view has loaded. When a child execution is selected, filters strictly to that
/// execution; otherwise shows all bugs of the parent product.
List<Ticket> scopeZenTaoBugs(Ref ref, List<Ticket> tickets) {
  final place = _place(ref);
  final selected = ref.watch(selectedZenTaoProductProvider);
  final product =
      selected != null &&
          selected.accountId == place.accountId &&
          selected.productId == place.scopeId
      ? selected
      : null;
  // Bugs are listed per product; until this board's product is picked (the
  // section picks one) there are none to show.
  if (product == null) return const [];
  final pickedExecution = ref.watch(selectedZenTaoExecutionProvider);
  final execution = pickedExecution?.accountId == product.accountId
      ? pickedExecution
      : null;
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

  // When a child execution is selected, narrow bugs exclusively to that execution.
  // When no execution is selected (parent product only), all bugs for this product are included.
  if (execution != null) {
    final execId = execution.executionId;
    tickets = tickets.where((t) {
      if (t.accountId != execution.accountId) return false;
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
        membershipLabel: zentaoProductLabel(product.productId),
        slice: null,
      ),
      loads: PagedViewLoads.of(streams),
      viewOf: (t) => ZenTaoBugStream.of(zentaoBugColumnFor(t), mine: mine),
      columnOf: zentaoBugColumnFor,
    ),
  );
}

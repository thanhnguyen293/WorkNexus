import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../domain/entities/assigned_work_item.dart';
import '../../domain/usecases/list_assigned_work.dart';

/// Accounts belonging to the active workspace.
final workspaceAccountsProvider = Provider<List<Account>>((ref) {
  final activeWs = ref.watch(activeWorkspaceProvider);
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  if (activeWs == null) return accounts;
  return accounts.where((a) => a.workspaceId == activeWs.id).toList();
});

/// List of open work items assigned to the user or awaiting their review,
/// across all connected tools in the active workspace (design §5).
final assignedWorkProvider = Provider<List<AssignedWorkItem>>((ref) {
  final tickets = ref.watch(ticketsProvider).asData?.value ?? const [];
  final accounts = ref.watch(workspaceAccountsProvider);
  const useCase = ListAssignedWork();
  return useCase(ListAssignedWorkInput(tickets: tickets, accounts: accounts));
});

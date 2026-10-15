import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/board/domain/usecases/is_assigned_to_me.dart';
import '../providers/zentao_board_providers.dart';
import '../providers/zentao_filter_providers.dart';

import 'zentao_popover_tree_node.dart';

/// Fallback demo projects when the account has no projects cached/synced yet.
const _fallbackDemoProjects = <ProviderProject>[
  ProviderProject(id: '12824', name: 'VN_Socialfi', accountId: 'default'),
  ProviderProject(id: '12169', name: 'VN_Wallet', accountId: 'default'),
  ProviderProject(id: '12167', name: 'VN_IM_Chat', accountId: 'default'),
  ProviderProject(id: '12166', name: 'VN_Website', accountId: 'default'),
  ProviderProject(
    id: '13100',
    name: 'HK_TBChat_Remastered',
    accountId: 'default',
  ),
  ProviderProject(id: '13101', name: 'HK_Wallet', accountId: 'default'),
];

/// Scrollable list of ZenTao projects prioritized by user's department.
class ZenTaoExecutionList extends ConsumerWidget {
  const ZenTaoExecutionList({
    super.key,
    this.account,
    required this.search,
    required this.isMine,
    required this.activeZone,
    required this.currentExec,
    required this.onSelectProject,
    required this.onSelectExecution,
  });

  final Account? account;
  final String search;
  final bool isMine;
  final String? activeZone;
  final ZenTaoExecutionSelection? currentExec;
  final ValueChanged<ProviderProject> onSelectProject;
  final ValueChanged<ProviderExecution> onSelectExecution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    final targetAccountId =
        account?.id ??
        switch (ref.watch(appNavProvider).rail) {
          AccountTarget(:final accountId) => accountId,
          _ => null,
        };

    final rawProjects = targetAccountId != null
        ? ref.watch(zentaoProjectsProvider(targetAccountId)).asData?.value
        : null;

    final projectList = (rawProjects != null && rawProjects.isNotEmpty)
        ? rawProjects
        : _fallbackDemoProjects;

    final tickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
    final userZone = ref.watch(userZoneProvider);
    final nav = ref.watch(appNavProvider);
    final currentScopeId = nav.currentLocation?.scopeId;

    int openCount(String projectId) => tickets
        .where(
          (t) =>
              (account == null || t.accountId == account!.id) &&
              t.projectId == projectId &&
              t.status != UnifiedStatus.done &&
              (t.externalType?.toLowerCase() == 'task' ||
                  t.providerEntity is ZenTaoTaskEntity),
        )
        .length;

    bool matchesDept(ProviderProject p, String dept) {
      if (dept.isEmpty) return false;
      final d = dept.toUpperCase();
      final name = p.name.toUpperCase();
      if (name.startsWith('${d}_') ||
          name.startsWith('$d-') ||
          name.startsWith('$d ') ||
          name.contains('_${d}_') ||
          name.contains('[$d]') ||
          name.startsWith(d)) {
        return true;
      }
      final prog = p.programName?.toUpperCase();
      if (prog != null && prog.contains(d)) {
        return true;
      }
      return false;
    }

    bool hasMyTickets(String projectId) {
      if (account == null) return false;
      const isAssigned = IsAssignedToMe();
      return tickets.any(
        (t) =>
            t.accountId == account!.id &&
            t.projectId == projectId &&
            isAssigned(t, account!),
      );
    }

    bool isMineProject(ProviderProject p) =>
        matchesDept(p, userZone) || hasMyTickets(p.id);

    final filtered = projectList.where((p) {
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        final nameMatch = p.name.toLowerCase().contains(q);
        final progMatch = p.programName?.toLowerCase().contains(q) ?? false;
        if (!nameMatch && !progMatch) return false;
      }

      if (activeZone != null && !matchesDept(p, activeZone!)) {
        return false;
      }

      if (isMine && !isMineProject(p)) {
        return false;
      }
      if (!isMine && isMineProject(p)) {
        return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDept = matchesDept(a, userZone);
      final bDept = matchesDept(b, userZone);
      if (aDept != bDept) {
        return aDept ? -1 : 1;
      }
      final countA = openCount(a.id);
      final countB = openCount(b.id);
      if (countA != countB) {
        return countB.compareTo(countA);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.folderSearch300,
                size: 28,
                color: c.textTertiary,
              ),
              const SizedBox(height: 8),
              Text(
                'No projects found',
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final item = filtered[i];
        final isFolderSelected =
            currentExec == null && currentScopeId == item.id;
        final count = openCount(item.id);

        return ZenTaoPopoverProjectNode(
          key: ValueKey('popover_proj_${item.id}'),
          targetAccountId: targetAccountId ?? 'default',
          project: item,
          isFolderSelected: isFolderSelected,
          currentExec: currentExec,
          openCount: count,
          onSelectProject: onSelectProject,
          onSelectExecution: onSelectExecution,
          initiallyExpanded: search.trim().isNotEmpty,
        );
      },
    );
  }
}

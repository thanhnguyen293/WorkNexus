import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/filter_tickets.dart' show savedViewMatches;
import '../../domain/value_objects/saved_view.dart';
import '../board_providers.dart';
import 'sidebar_primitives.dart';

/// Saved views (All / Today / Mine / Review / Blocked) with live counts.
class ViewsSection extends ConsumerWidget {
  const ViewsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final filter = ref.watch(filterStateProvider);
    final tickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
    final lookups = ref.watch(lookupsProvider);
    final now = DateTime.now();

    // Scope to the active workspace (design uses scopeTasks for view counts).
    final scoped = tickets.where((tk) {
      if (filter.workspaceId == 'all') return true;
      final acc = lookups.accounts[tk.accountId];
      return acc?.workspaceId == filter.workspaceId;
    }).toList();

    const icons = {
      SavedView.all: '▤',
      SavedView.today: '◷',
      SavedView.mine: '◈',
      SavedView.review: '◍',
      SavedView.blocked: '⊘',
    };
    String label(SavedView v) => switch (v) {
      SavedView.all => l.viewAll,
      SavedView.today => l.viewToday,
      SavedView.mine => l.viewMine,
      SavedView.review => l.viewReview,
      SavedView.blocked => l.viewBlocked,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarSectionLabel(l.views),
        for (final v in SavedView.values)
          SidebarNavRow(
            leading: Text(
              icons[v]!,
              style: context.typography.bodySm.copyWith(
                color: filter.savedView == v ? c.accent : c.textTertiary,
              ),
            ),
            label: label(v),
            count: scoped.where((tk) => savedViewMatches(v, tk, now)).length,
            active: filter.savedView == v,
            onTap: () => ref.read(filterStateProvider.notifier).setSavedView(v),
          ),
      ],
    );
  }
}

/// The workspace picker (All workspaces + one row per workspace).
class WorkspaceSection extends ConsumerWidget {
  const WorkspaceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final filter = ref.watch(filterStateProvider);
    final tickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
    final lookups = ref.watch(lookupsProvider);
    final workspaces = lookups.workspaces.values.toList();

    int wsCount(String id) => tickets
        .where((tk) => lookups.accounts[tk.accountId]?.workspaceId == id)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarSectionLabel(l.workspace),
        SidebarNavRow(
          height: 33,
          leading: SizedBox(
            width: 18,
            child: Center(
              child: Text(
                '∗',
                style: context.typography.body.copyWith(color: c.textTertiary),
              ),
            ),
          ),
          label: l.allWorkspaces,
          count: tickets.length,
          active: filter.workspaceId == 'all',
          onTap: () =>
              ref.read(filterStateProvider.notifier).setWorkspace('all'),
        ),
        for (final w in workspaces)
          SidebarNavRow(
            height: 33,
            leading: WorkspaceBadge(Color(w.colorValue), w.shortCode),
            label: w.isPersonal ? l.personal : w.name,
            count: wsCount(w.id),
            active: filter.workspaceId == w.id,
            onTap: () =>
                ref.read(filterStateProvider.notifier).setWorkspace(w.id),
          ),
      ],
    );
  }
}

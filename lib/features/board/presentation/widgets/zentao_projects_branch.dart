import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'sidebar_primitives.dart';
import 'zentao_project_row.dart';

/// The children of a ZenTao node: pinned projects listed directly, then a
/// collapsible "Projects" group (collapsed by default) holding the rest.
class ZenTaoProjectsBranch extends ConsumerWidget {
  const ZenTaoProjectsBranch({
    super.key,
    required this.account,
    required this.tickets,
  });

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final products = ref.watch(zentaoProductsProvider(account.id));
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );

    String keyOf(ProviderProduct p) => '${p.accountId}:${p.id}';

    return products.when(
      data: (items) {
        final pinnedItems = [
          for (final p in items)
            if (pinned.contains(keyOf(p))) p,
        ];
        final rest = [
          for (final p in items)
            if (!pinned.contains(keyOf(p))) p,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in pinnedItems)
              ZenTaoProjectRow(product: p, tickets: tickets, pinned: true),
            _ProjectsGroup(
              accountId: account.id,
              projects: rest,
              tickets: tickets,
            ),
          ],
        );
      },
      loading: () => _MutedRow(label: l.loadingProjects),
      error: (_, _) => _MutedRow(label: l.projectsUnavailable),
    );
  }
}

class _ProjectsGroup extends ConsumerWidget {
  const _ProjectsGroup({
    required this.accountId,
    required this.projects,
    required this.tickets,
  });

  final String accountId;
  final List<ProviderProduct> projects;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final expanded = ref.watch(
      zentaoProjectsExpandedProvider.select((s) => s.contains(accountId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => ref
              .read(zentaoProjectsExpandedProvider.notifier)
              .toggle(accountId),
          borderRadius: BorderRadius.circular(context.radii.sm),
          child: Container(
            height: 27,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: c.textTertiary,
                ),
                SizedBox(width: context.spacing.xs),
                Expanded(
                  child: Text(
                    l.projects,
                    style: context.typography.mono.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${projects.length}',
                  style: context.typography.monoXs.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          SidebarTreeBranch(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in projects)
                  ZenTaoProjectRow(product: p, tickets: tickets, pinned: false),
              ],
            ),
          ),
      ],
    );
  }
}

class _MutedRow extends StatelessWidget {
  const _MutedRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 27,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.typography.mono.copyWith(
                fontWeight: FontWeight.w500,
                color: c.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

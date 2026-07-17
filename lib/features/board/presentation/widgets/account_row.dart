import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../board_providers.dart';

/// An account node in the sources tree, with its projects nested beneath.
class AccountRow extends ConsumerWidget {
  const AccountRow({
    super.key,
    required this.account,
    required this.tickets,
    required this.lookups,
  });
  final Account account;
  final List<Ticket> tickets;
  final Lookups lookups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final filter = ref.watch(filterStateProvider);
    final accTickets = tickets
        .where((tk) => tk.accountId == account.id)
        .toList();
    final projectIds = {for (final tk in accTickets) tk.projectId};
    final active = filter.accountIds.contains(account.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              ref.read(filterStateProvider.notifier).toggleAccount(account.id),
          borderRadius: BorderRadius.circular(context.radii.sm),
          child: Container(
            height: 27,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            decoration: BoxDecoration(
              color: active ? c.selectionFill : Colors.transparent,
              borderRadius: BorderRadius.circular(context.radii.sm),
            ),
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
                    account.handle,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.mono.copyWith(
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${accTickets.length}',
                  style: context.typography.monoXs.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: context.spacing.sm),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: c.border)),
            ),
            padding: EdgeInsets.only(left: context.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final pid in projectIds)
                  _ProjectRow(
                    projectId: pid,
                    name: lookups.projects[pid]?.name ?? pid,
                    count: accTickets.where((tk) => tk.projectId == pid).length,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectRow extends ConsumerWidget {
  const _ProjectRow({
    required this.projectId,
    required this.name,
    required this.count,
  });
  final String projectId;
  final String name;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final active = ref.watch(
      filterStateProvider.select((f) => f.projectIds.contains(projectId)),
    );
    return InkWell(
      onTap: () =>
          ref.read(filterStateProvider.notifier).toggleProject(projectId),
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Container(
        height: 25,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
        decoration: BoxDecoration(
          color: active ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.sm),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: c.textTertiary,
                borderRadius: BorderRadius.circular(context.radii.dot),
              ),
            ),
            SizedBox(width: context.spacing.sm),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: context.typography.meta.copyWith(
                  color: active ? c.textPrimary : c.textSecondary,
                ),
              ),
            ),
            Text(
              '$count',
              style: context.typography.monoXs.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

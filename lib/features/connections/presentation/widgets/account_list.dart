import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/credential_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import '../../domain/repositories/connection_repository.dart';

/// A workspace heading followed by its connected accounts.
class WorkspaceAccounts extends StatelessWidget {
  const WorkspaceAccounts({
    super.key,
    required this.workspaceId,
    required this.lookups,
    required this.tickets,
  });
  final String workspaceId;
  final Lookups lookups;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final ws = lookups.workspaces[workspaceId];
    if (ws == null) return const SizedBox.shrink();
    final accounts = lookups.accounts.values
        .where((a) => a.workspaceId == workspaceId)
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xl4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WorkspaceBadge(Color(ws.colorValue), ws.shortCode, big: true),
              SizedBox(width: context.spacing.md),
              Text(
                ws.isPersonal ? l.personal : ws.name,
                style: context.typography.bodyStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
              SizedBox(width: context.spacing.lg),
              Expanded(child: Container(height: 1, color: c.border)),
              SizedBox(width: context.spacing.lg),
              Text(
                '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(context.radii.md),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < accounts.length; i++)
                  _AccountRow(
                    account: accounts[i],
                    lookups: lookups,
                    tickets: tickets,
                    first: i == 0,
                    index: i,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({
    required this.account,
    required this.lookups,
    required this.tickets,
    required this.first,
    required this.index,
  });
  final Account account;
  final Lookups lookups;
  final List<Ticket> tickets;
  final bool first;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isLive = account.credentialsRef != null;
    final l = AppL10n.of(context);
    final accTickets = tickets
        .where((tk) => tk.accountId == account.id)
        .toList();
    final projects = {
      for (final tk in accTickets) lookups.projects[tk.projectId]?.name ?? '',
    }.where((s) => s.isNotEmpty).toList();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xl2,
        vertical: context.spacing.xl,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: first ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          ProviderBadge(account.providerType, big: true),
          SizedBox(width: context.spacing.xl),
          Expanded(
            child: Row(
              children: [
                Text(
                  account.handle,
                  style: context.typography.monoStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                SizedBox(width: context.spacing.md),
                Text(
                  account.providerType.displayName,
                  style: context.typography.captionSm.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
          ),
          SizedBox(width: context.spacing.sm),
          Text(
            l.connected,
            style: context.typography.caption.copyWith(color: c.textSecondary),
          ),
          SizedBox(width: context.spacing.xl),
          if (isLive) ...[
            IconButton(
              tooltip: 'Sync now',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.sync, size: 16, color: c.textSecondary),
              onPressed: () => _sync(context, ref),
            ),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, size: 16, color: c.textTertiary),
              onPressed: () => _remove(ref),
            ),
          ] else
            Text(
              '${2 + index}m synced',
              style: context.typography.monoSm.copyWith(color: c.textTertiary),
            ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Syncing ${account.handle}…')),
    );
    final res = await getIt<SyncService>().syncAccount(account);
    final msg = switch (res) {
      Ok(:final value) => 'Synced $value tickets from ${account.handle}',
      Err(:final failure) => 'Sync failed: ${failure.message}',
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _remove(WidgetRef ref) async {
    await getIt<ConnectionRepository>().removeAccount(account.id);
    final credRef = account.credentialsRef;
    if (credRef != null) {
      await getIt<CredentialStore>().delete(credRef);
    }
  }
}

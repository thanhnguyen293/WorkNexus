import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/platform/credential_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/repositories/connection_repository.dart';
import 'account_row.dart';
import 'workspace_editor_dialog.dart';

/// A workspace heading followed by its connected accounts.
class WorkspaceAccounts extends StatelessWidget {
  const WorkspaceAccounts({
    super.key,
    required this.workspaceId,
    required this.lookups,
  });
  final String workspaceId;
  final Lookups lookups;

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
              WorkspaceBadge(
                Color(ws.colorValue),
                ws.shortCode,
                big: true,
                iconKey: ws.iconKey,
              ),
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
              SizedBox(width: context.spacing.sm),
              IconButton(
                tooltip: 'Edit workspace',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  PhosphorIconsLight.palette,
                  size: 16,
                  color: c.textSecondary,
                ),
                onPressed: () => _editWorkspace(context, ws),
              ),
              IconButton(
                tooltip: 'Delete workspace',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  PhosphorIconsLight.trash,
                  size: 16,
                  color: c.textTertiary,
                ),
                onPressed: () => _deleteWorkspace(context, ws.id, accounts),
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
                  AccountRow(
                    account: accounts[i],
                    lookups: lookups,
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

  Future<void> _editWorkspace(BuildContext context, Workspace workspace) async {
    final updated = await showDialog<Workspace>(
      context: context,
      builder: (_) => WorkspaceEditorDialog(workspace: workspace),
    );
    if (updated == null) return;
    await getIt<ConnectionRepository>().updateWorkspace(updated);
  }

  Future<void> _deleteWorkspace(
    BuildContext context,
    String id,
    List<Account> accounts,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DeleteWorkspaceDialog(
        accountCount: accounts.length,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onDelete: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true) return;
    final credentials = await getIt<ConnectionRepository>().deleteWorkspace(id);
    for (final ref in credentials) {
      await getIt<CredentialStore>().delete(ref);
    }
  }
}

class _DeleteWorkspaceDialog extends StatelessWidget {
  const _DeleteWorkspaceDialog({
    required this.accountCount,
    required this.onCancel,
    required this.onDelete,
  });

  final int accountCount;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accountLabel = accountCount == 1 ? 'account' : 'accounts';
    return Dialog(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.all(context.spacing.xl3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(context.spacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(PhosphorIconsLight.trash, size: 20, color: c.error),
                  SizedBox(width: context.spacing.md),
                  Expanded(
                    child: Text(
                      'Delete workspace?',
                      style: context.typography.titleLg.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing.lg),
              Text(
                'This removes $accountCount $accountLabel and local synced '
                'data in this workspace.',
                style: context.typography.secondary.copyWith(
                  color: c.textSecondary,
                  height: 1.45,
                ),
              ),
              SizedBox(height: context.spacing.xl2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: context.spacing.sm,
                children: [
                  AppButton.textNeutral(
                    size: AppButtonSize.small,
                    onPressed: onDelete,
                    child: Text('Delete', style: TextStyle(color: c.error)),
                  ),
                  AppButton.filled(
                    size: AppButtonSize.small,
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

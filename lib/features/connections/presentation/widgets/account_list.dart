import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/platform/credential_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon_button.dart';
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
    final s = context.spacing;
    final l = AppL10n.of(context);
    final ws = lookups.workspaces[workspaceId];
    if (ws == null) return const SizedBox.shrink();
    final accounts = lookups.accounts.values
        .where((a) => a.workspaceId == workspaceId)
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: s.xl4),
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
              SizedBox(width: s.md),
              Flexible(
                child: Text(
                  ws.isPersonal ? l.personal : ws.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: s.lg),
              Expanded(child: Divider(height: 1, color: c.border)),
              SizedBox(width: s.lg),
              Text(
                l.connectionsAccountCount(accounts.length),
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
              SizedBox(width: s.sm),
              AppIconButton(
                icon: LucideIcons.palette300,
                tooltip: l.connectionsEditWorkspace,
                onPressed: () => _editWorkspace(context, ws),
              ),
              AppIconButton(
                icon: LucideIcons.trash300,
                tooltip: l.connectionsDeleteWorkspace,
                onPressed: () => _deleteWorkspace(context, ws.id, accounts),
              ),
            ],
          ),
          SizedBox(height: s.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(context.radii.lg),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < accounts.length; i++)
                  AccountRow(
                    account: accounts[i],
                    lookups: lookups,
                    first: i == 0,
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
    final l = AppL10n.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l.connectionsDeleteWorkspaceTitle,
      message: l.connectionsDeleteWorkspaceMessage(accounts.length),
      destructive: true,
    );
    if (!confirmed) return;
    final credentials = await getIt<ConnectionRepository>().deleteWorkspace(id);
    for (final ref in credentials) {
      await getIt<CredentialStore>().delete(ref);
    }
  }
}

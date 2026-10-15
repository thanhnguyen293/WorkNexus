import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/account_sync_service.dart';
import '../../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/credential_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/repositories/connection_repository.dart';

/// The GitLab instance version for an account (e.g. `16.3.8`), shown on its
/// connected-accounts row. Null for non-GitLab accounts or when unavailable.
final gitlabServerVersionProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, accountId) =>
          getIt<GitLabMrService>().gitlabServerVersion(accountId),
    );

/// One connected account: provider, handle, the server it talks to, and its
/// sync / remove actions.
class AccountRow extends ConsumerWidget {
  const AccountRow({
    super.key,
    required this.account,
    required this.lookups,
    required this.first,
  });
  final Account account;
  final Lookups lookups;
  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isLive = account.credentialsRef != null;
    final l = AppL10n.of(context);
    // GitLab instance version, once probed (null while loading / non-GitLab).
    final gitlabVersion = account.providerType == ProviderType.gitlab
        ? ref.watch(gitlabServerVersionProvider(account.id)).asData?.value
        : null;
    final serverUrl = _serverUrl(account.baseUrl);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.monoStrong.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: context.spacing.md),
                    Text(
                      account.providerType.displayName,
                      style: context.typography.captionSm.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                    if (gitlabVersion != null) ...[
                      SizedBox(width: context.spacing.sm),
                      Text(
                        'v$gitlabVersion',
                        style: context.typography.captionSm.copyWith(
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (serverUrl != null) ...[
                  SizedBox(height: context.spacing.xs),
                  Tooltip(
                    message: serverUrl,
                    child: Text(
                      serverUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.monoSm.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: context.spacing.sm,
            height: context.spacing.sm,
            decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
          ),
          SizedBox(width: context.spacing.sm),
          Text(
            l.connected,
            style: context.typography.caption.copyWith(color: c.textSecondary),
          ),
          if (isLive) ...[
            SizedBox(width: context.spacing.xl),
            AppIconButton(
              icon: LucideIcons.refreshCw300,
              tooltip: l.connectionsSyncNow,
              onPressed: () => _sync(context),
            ),
            AppIconButton(
              icon: LucideIcons.trash300,
              tooltip: l.connectionsRemoveAccount,
              onPressed: () => _remove(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    final l = AppL10n.of(context);
    showAppSnack(context, l.connectionsSyncing(account.handle));
    final res = await getIt<AccountSyncService>().syncAccount(account);
    if (!context.mounted) return;
    switch (res) {
      case Ok(:final value):
        showAppSnack(context, l.connectionsSynced(value, account.handle));
      case Err(:final failure):
        showAppSnack(
          context,
          l.connectionsSyncFailed(account.handle, failure.message),
          isError: true,
        );
    }
  }

  Future<void> _remove(BuildContext context) async {
    final l = AppL10n.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l.connectionsRemoveAccountTitle(account.handle),
      message: l.connectionsRemoveAccountMessage,
      confirmLabel: l.connectionsRemoveConfirm,
      destructive: true,
    );
    if (!confirmed) return;
    await getIt<ConnectionRepository>().removeAccount(account.id);
    final credRef = account.credentialsRef;
    if (credRef != null) {
      await getIt<CredentialStore>().delete(credRef);
    }
  }

  /// The instance the account talks to, without a trailing slash; null when
  /// the account has none recorded.
  static String? _serverUrl(String? baseUrl) {
    final url = baseUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}

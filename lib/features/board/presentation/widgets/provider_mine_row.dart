import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/github_item_kind.dart';
import '../../domain/value_objects/gitlab_item_kind.dart';
import '../board_providers.dart';

/// Sidebar row opening the account-wide "my merge/pull requests" board — every
/// MR/PR (assigned to me or requesting my review) across all of the account's
/// projects, mirroring GitLab's "Assigned merge requests" dashboard.
class ProviderMineRow extends ConsumerWidget {
  const ProviderMineRow({super.key, required this.account});

  final Account account;

  bool get _isGitLab => account.providerType == ProviderType.gitlab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final active = _isGitLab
        ? ref.watch(
            selectedGitLabProjectProvider.select(
              (s) => s?.mine == true && s?.accountId == account.id,
            ),
          )
        : ref.watch(
            selectedGitHubRepoProvider.select(
              (s) => s?.mine == true && s?.accountId == account.id,
            ),
          );
    final loading =
        active &&
        (_isGitLab
            ? ref.watch(gitlabMineSliceProvider).isLoading
            : ref.watch(githubMineSliceProvider).isLoading);
    final label = _isGitLab ? l.gitlabMergeRequests : l.githubPullRequests;

    return Opacity(
      opacity: loading ? 0.48 : 1,
      child: InkWell(
        onTap: loading ? null : () => _select(ref),
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
              Icon(Icons.merge_type, size: 14, color: c.textTertiary),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.mono.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens this account's "mine" board: clears other selections/filters, marks
  /// the mine selection, sets the MR/PR kind, and switches the view mode.
  void _select(WidgetRef ref) {
    ref.read(settingsOpenProvider.notifier).state = false;
    ref.read(filterStateProvider.notifier).clearAll();
    ref.read(selectedZenTaoProductProvider.notifier).clear();
    ref.read(selectedZenTaoExecutionProvider.notifier).clear();
    if (_isGitLab) {
      ref.read(selectedGitHubRepoProvider.notifier).clear();
      ref.read(selectedGitLabProjectProvider.notifier).selectMine(account.id);
      ref.read(gitlabKindProvider.notifier).set(GitLabItemKind.mergeRequest);
      ref.read(viewModeProvider.notifier).set(ViewMode.gitlab);
    } else {
      ref.read(selectedGitLabProjectProvider.notifier).clear();
      ref.read(selectedGitHubRepoProvider.notifier).selectMine(account.id);
      ref.read(githubKindProvider.notifier).set(GitHubItemKind.pullRequest);
      ref.read(viewModeProvider.notifier).set(ViewMode.github);
    }
  }
}

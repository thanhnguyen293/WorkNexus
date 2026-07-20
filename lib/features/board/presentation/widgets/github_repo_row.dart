import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/github_item_kind.dart';
import '../board_providers.dart';
import 'sidebar_primitives.dart';

/// A single GitHub repo row: a dot, the repo name and a pin toggle. Tapping
/// opens the repo's dedicated board (Issues by default), which then fetches
/// that kind's recent items from GitHub.
class GitHubRepoRow extends ConsumerWidget {
  const GitHubRepoRow({
    super.key,
    required this.repo,
    required this.tickets,
    required this.pinned,
  });

  final ProviderProject repo;
  final List<Ticket> tickets;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final selected = ref.watch(selectedGitHubRepoProvider);
    final active =
        selected?.accountId == repo.accountId && selected?.repoId == repo.id;
    final loading = active && ref.watch(githubItemsSliceProvider).isLoading;

    return Opacity(
      opacity: loading ? 0.48 : 1,
      child: InkWell(
        onTap: loading ? null : () => _select(ref),
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Container(
          height: 27,
          padding: EdgeInsets.only(
            left: context.spacing.sm,
            right: context.spacing.xxs,
          ),
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
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  repo.name,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.mono.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: context.spacing.xs),
              SidebarPinButton(
                pinned: pinned,
                tooltip: pinned ? l.unpinRepository : l.pinRepository,
                onTap: () => ref
                    .read(appSettingsProvider.notifier)
                    .togglePinnedProject('${repo.accountId}:${repo.id}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens this repo's board: clears any ZenTao/GitLab selection, selects the
  /// repo, resets to the Issues kind, and switches to the GitHub view mode.
  void _select(WidgetRef ref) {
    ref.read(settingsOpenProvider.notifier).state = false;
    // Drop any filters from the previous board (e.g. the ZenTao "my tickets"
    // assignee), which don't apply to GitHub and would empty the board.
    ref.read(filterStateProvider.notifier).clearAll();
    ref.read(selectedZenTaoProductProvider.notifier).clear();
    ref.read(selectedZenTaoExecutionProvider.notifier).clear();
    ref.read(selectedGitLabProjectProvider.notifier).clear();
    ref.read(selectedGitHubRepoProvider.notifier).select(repo);
    ref.read(githubKindProvider.notifier).set(GitHubItemKind.issue);
    ref.read(viewModeProvider.notifier).set(ViewMode.github);
  }
}

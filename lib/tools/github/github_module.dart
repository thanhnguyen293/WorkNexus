import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/domain/entities/account.dart';
import '../../core/domain/entities/provider_entity.dart';
import '../../core/domain/entities/ticket.dart';
import '../../core/domain/value_objects/provider_type.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/tools/tool_module.dart';
import '../../core/widgets/coming_soon_view.dart';
import '../../l10n/app_localizations.dart';
import 'presentation/detail/github_detail_sections.dart';
import 'presentation/detail/github_pr_detail.dart';
import 'presentation/detail/github_ticket_actions.dart';
import 'presentation/nav/github_nav_pane.dart';
import 'presentation/providers/github_metrics_providers.dart';
import 'presentation/providers/github_scope.dart';
import 'presentation/sections/github_issues_section.dart';
import 'presentation/sections/github_pulls_section.dart';

class GithubModule extends ToolModule {
  const GithubModule();

  @override
  ProviderType get providerType => ProviderType.github;

  @override
  SectionId get defaultSection => const SectionId('github.pulls');

  @override
  String Function(AppL10n) get roleLabel =>
      (l) => l.roleCodeHosting;

  @override
  List<ToolSection> get sections => [
    ToolSection(
      id: const SectionId('github.pulls'),
      label: (l) => l.githubPullRequests,
      icon: LucideIcons.gitPullRequest300,
      scopeKind: ScopeKind.repository,
      viewModes: GithubPullsSection.modes,
    ),
    ToolSection(
      id: const SectionId('github.issues'),
      label: (l) => l.githubIssues,
      icon: LucideIcons.circleDot300,
      scopeKind: ScopeKind.repository,
      viewModes: GithubIssuesSection.modes,
    ),
    ToolSection(
      id: const SectionId('github.actions'),
      label: (l) => l.actions,
      icon: LucideIcons.play300,
      scopeKind: ScopeKind.none,
      available: false,
    ),
  ];

  @override
  Widget buildNavPane(
    BuildContext context,
    Account account,
    ToolLocation location,
  ) {
    return GithubNavPane(
      account: account,
      location: location,
      sections: sections,
    );
  }

  @override
  Widget buildSection(
    BuildContext context,
    Account account,
    ToolLocation location,
  ) {
    switch (location.section.value) {
      case 'github.pulls':
        return GithubPullsSection(account: account, location: location);
      case 'github.issues':
        return GithubIssuesSection(account: account, location: location);
      case 'github.actions':
        return ComingSoonView(
          icon: LucideIcons.play300,
          title: AppL10n.of(context).actions,
          body: '',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  ProviderListenable<AsyncValue<ToolMetrics>> metrics(Account account) {
    return computeGithubMetricsProvider(account.id);
  }

  @override
  Uri? webUrl(Account account, ToolLocation location) {
    final rawBase = account.baseUrl;
    final baseUrl = (rawBase != null && rawBase.isNotEmpty)
        ? rawBase
        : 'https://github.com';
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    if (location.scopeId != null) {
      if (location.section.value == 'github.issues') {
        return Uri.tryParse('$root/${location.scopeId}/issues');
      }
      return Uri.tryParse('$root/${location.scopeId}/pulls');
    }

    if (location.section.value == 'github.issues') {
      return Uri.tryParse('$root/issues');
    }
    return Uri.tryParse('$root/pulls');
  }

  @override
  Widget? buildDetail(
    BuildContext context,
    Ticket ticket, {
    VoidCallback? onClose,
  }) {
    final isPr = (ticket.externalType ?? '').toLowerCase() == 'pullrequest';
    final entity = ticket.providerEntity;
    if (isPr && entity is GitHubItemEntity) {
      return GitHubPrDetail(
        ticket: ticket,
        entity: entity,
        isSyncing: false,
        onClose: onClose ?? () {},
      );
    }
    return null;
  }

  @override
  Widget? buildActions(BuildContext context, Ticket ticket) {
    return GitHubActions(ticket: ticket);
  }

  @override
  Widget? buildDetailSidebar(BuildContext context, Ticket ticket) {
    if (ticket.providerEntity case final GitHubItemEntity entity) {
      return GitHubDetailSections(ticket: ticket, entity: entity);
    }
    return null;
  }

  @override
  List<Ticket> scopeTickets(
    Ref ref,
    ToolLocation location,
    List<Ticket> tickets,
  ) => scopeGitHubTickets(
    tickets,
    accountId: switch (ref.watch(railTargetProvider)) {
      AccountTarget(:final accountId) => accountId,
      WorkspaceTarget() => null,
    },
    scopeId: location.scopeId,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/domain/entities/account.dart';
import '../../core/domain/entities/provider_entity.dart';
import '../../core/domain/entities/ticket.dart';
import '../../core/domain/value_objects/provider_type.dart';
import '../../core/navigation/app_nav_state.dart';
import '../../core/tools/tool_module.dart';
import '../../core/widgets/coming_soon_view.dart';
import '../../l10n/app_localizations.dart';
import 'presentation/detail/gitlab_detail_sections.dart';
import 'presentation/detail/gitlab_mr_detail.dart';
import 'presentation/detail/gitlab_ticket_actions.dart';
import 'presentation/nav/gitlab_nav_pane.dart';
import 'presentation/providers/gitlab_metrics_providers.dart';
import 'presentation/sections/gitlab_issues_section.dart';
import 'presentation/sections/gitlab_mrs_section.dart';

class GitlabModule extends ToolModule {
  const GitlabModule();

  @override
  ProviderType get providerType => ProviderType.gitlab;

  @override
  SectionId get defaultSection => const SectionId('gitlab.mrs');

  @override
  String Function(AppL10n) get roleLabel =>
      (l) => l.roleCodeHostingCi;

  @override
  List<ToolSection> get sections => [
    ToolSection(
      id: const SectionId('gitlab.mrs'),
      label: (l) => l.gitlabMergeRequests,
      icon: LucideIcons.gitPullRequest300,
      scopeKind: ScopeKind.repository,
      viewModes: GitlabMrsSection.modes,
    ),
    ToolSection(
      id: const SectionId('gitlab.issues'),
      label: (l) => l.gitlabIssues,
      icon: LucideIcons.circleDot300,
      scopeKind: ScopeKind.repository,
      viewModes: GitlabIssuesSection.modes,
    ),
    ToolSection(
      id: const SectionId('gitlab.pipelines'),
      label: (l) => l.pipelines,
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
    return GitlabNavPane(
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
      case 'gitlab.mrs':
        return GitlabMrsSection(account: account, location: location);
      case 'gitlab.issues':
        return GitlabIssuesSection(account: account, location: location);
      case 'gitlab.pipelines':
        return ComingSoonView(
          icon: LucideIcons.play300,
          title: AppL10n.of(context).pipelines,
          body: '',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  ProviderListenable<AsyncValue<ToolMetrics>> metrics(Account account) {
    return computeGitlabMetricsProvider(account.id);
  }

  @override
  Uri? webUrl(Account account, ToolLocation location) {
    final rawBase = account.baseUrl;
    final baseUrl = (rawBase != null && rawBase.isNotEmpty)
        ? rawBase
        : 'https://gitlab.com';
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    if (location.scopeId != null) {
      if (location.section.value == 'gitlab.issues') {
        return Uri.tryParse('$root/${location.scopeId}/-/issues');
      }
      return Uri.tryParse('$root/${location.scopeId}/-/merge_requests');
    }

    if (location.section.value == 'gitlab.issues') {
      return Uri.tryParse('$root/dashboard/issues');
    }
    return Uri.tryParse('$root/dashboard/merge_requests');
  }

  @override
  Widget? buildDetail(
    BuildContext context,
    Ticket ticket, {
    VoidCallback? onClose,
  }) {
    final isMr = (ticket.externalType ?? '').toLowerCase() == 'mergerequest';
    final entity = ticket.providerEntity;
    if (isMr && entity is GitLabItemEntity) {
      return GitLabMrDetail(
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
    return GitLabActions(ticket: ticket);
  }

  @override
  Widget? buildDetailSidebar(BuildContext context, Ticket ticket) {
    if (ticket.providerEntity case final GitLabItemEntity entity) {
      return GitLabDetailSections(ticket: ticket, entity: entity);
    }
    return null;
  }
}

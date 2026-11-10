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
import '../../l10n/app_localizations.dart';
import 'presentation/detail/bug_attachments.dart';
import 'presentation/detail/bug_detail_sections.dart';
import 'presentation/detail/bug_status_strip.dart';
import 'presentation/detail/parent_task_link.dart';
import 'presentation/detail/subtask_list.dart';
import 'presentation/detail/task_detail_sections.dart';
import 'presentation/detail/task_effort_bar.dart';
import 'presentation/detail/zentao_ticket_actions.dart';
import 'presentation/nav/zentao_nav_pane.dart';
import 'presentation/providers/zentao_metrics_providers.dart';
import 'presentation/providers/zentao_scope_providers.dart';
import 'presentation/providers/zentao_scope_title_provider.dart';
import 'presentation/sections/zentao_bugs_section.dart';
import 'presentation/sections/zentao_docs_section.dart';
import 'presentation/sections/zentao_tasks_section.dart';

class ZentaoModule extends ToolModule {
  const ZentaoModule();

  @override
  ProviderType get providerType => ProviderType.zentao;

  @override
  SectionId get defaultSection => const SectionId('zentao.tasks');

  @override
  bool get sectionsOnRail => true;

  @override
  String Function(AppL10n) get roleLabel =>
      (l) => l.roleProjectManagement;

  @override
  List<ToolSection> get sections => [
    ToolSection(
      id: const SectionId('zentao.tasks'),
      label: (l) => l.tasks,
      icon: LucideIcons.listChecks300,
      scopeKind: ScopeKind.project,
      viewModes: ZentaoTasksSection.modes,
    ),
    ToolSection(
      id: const SectionId('zentao.bugs'),
      label: (l) => l.bugs,
      icon: LucideIcons.bug300,
      scopeKind: ScopeKind.product,
      viewModes: ZentaoBugsSection.modes,
    ),
    ToolSection(
      id: const SectionId('zentao.docs'),
      label: (l) => l.docs,
      icon: LucideIcons.bookOpen300,
      scopeKind: ScopeKind.library,
    ),
  ];

  @override
  Widget buildNavPane(
    BuildContext context,
    Account account,
    ToolLocation location,
  ) {
    return ZentaoNavPane(
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
      case 'zentao.tasks':
        return ZentaoTasksSection(account: account, location: location);
      case 'zentao.bugs':
        return ZentaoBugsSection(account: account, location: location);
      case 'zentao.docs':
        return ZentaoDocsSection(account: account, location: location);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  ProviderListenable<AsyncValue<ToolMetrics>> metrics(Account account) {
    return computeZentaoMetricsProvider(account.id);
  }

  @override
  ProviderListenable<String?>? scopeTitle(
    Account account,
    ToolLocation location,
  ) => zentaoScopeTitleProvider((
    accountId: account.id,
    scopeId: location.scopeId,
    bugs: location.section.value == 'zentao.bugs',
  ));

  /// Docs' libraries tree folds away, so a document can take the width.
  @override
  bool paneCollapsible(ToolLocation location) =>
      location.section.value == 'zentao.docs';

  @override
  Uri? webUrl(Account account, ToolLocation location) {
    final baseUrl = account.baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) return null;
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    if (location.section.value == 'zentao.docs') {
      return Uri.tryParse('$root/doc-index.html');
    }

    if (location.scopeId != null) {
      if (location.section.value == 'zentao.bugs') {
        return Uri.tryParse('$root/product-browse-${location.scopeId}.html');
      }
      return Uri.tryParse('$root/project-task-${location.scopeId}.html');
    }

    if (location.section.value == 'zentao.bugs') {
      return Uri.tryParse('$root/product.html');
    }
    return Uri.tryParse('$root/project.html');
  }

  @override
  Widget? buildDetail(
    BuildContext context,
    Ticket ticket, {
    VoidCallback? onClose,
  }) {
    // ZenTao uses the standard tabbed panel
    return null;
  }

  @override
  Widget? buildActions(BuildContext context, Ticket ticket) {
    return ZenTaoActions(ticket: ticket);
  }

  @override
  List<Ticket> scopeTickets(
    Ref ref,
    ToolLocation location,
    List<Ticket> tickets,
  ) => switch (location.section.value) {
    'zentao.tasks' => scopeZenTaoTasks(ref, tickets),
    'zentao.bugs' => scopeZenTaoBugs(ref, tickets),
    _ => tickets,
  };

  @override
  Widget? buildDetailHeaderExtras(BuildContext context, Ticket ticket) {
    if (ticket.providerEntity case ZenTaoTaskEntity(
      :final parentId?,
      :final parentName,
    )) {
      return ParentTaskLink(
        ticket: ticket,
        parentId: parentId,
        parentName: parentName,
      );
    }
    return null;
  }

  @override
  Widget? buildStatusStrip(BuildContext context, Ticket ticket) {
    if (ticket.providerEntity case final ZenTaoBugEntity bug) {
      return BugStatusStrip(ticket: ticket, bug: bug);
    }
    return null;
  }

  @override
  Widget? buildDetailEffort(BuildContext context, Ticket ticket) {
    if (ticket.providerEntity case final ZenTaoTaskEntity task) {
      return TaskEffortBar(task: task);
    }
    return null;
  }

  @override
  Widget? buildDetailSubtasks(BuildContext context, Ticket ticket) {
    if (ticket.providerEntity case final ZenTaoTaskEntity task) {
      if (task.subtasks.isNotEmpty) {
        return SubtaskList(ticket: ticket, subtasks: task.subtasks);
      }
    }
    return null;
  }

  @override
  Widget? buildDetailAttachments(BuildContext context, Ticket ticket) {
    if (ticket.providerEntity case final ZenTaoBugEntity bug) {
      if (bug.attachments.isNotEmpty) {
        return BugAttachments(ticket: ticket, attachments: bug.attachments);
      }
    }
    return null;
  }

  @override
  Widget? buildDetailSidebar(BuildContext context, Ticket ticket) {
    if (ticket.providerEntity case final ZenTaoBugEntity bug) {
      return ZenTaoBugSections(bug, ticket: ticket);
    }
    if (ticket.providerEntity case final ZenTaoTaskEntity task) {
      return ZenTaoTaskSections(task, ticket: ticket);
    }
    return null;
  }
}

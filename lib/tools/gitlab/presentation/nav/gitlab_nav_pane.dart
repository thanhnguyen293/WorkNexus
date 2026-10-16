import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../shared/shell_pane/feature_tab_strip.dart';
import '../../../../shared/shell_pane/tool_pane_header.dart';
import '../../../../shared/shell_pane/tool_pane_scaffold.dart';
import 'gitlab_projects_scope_list.dart';

/// Navigation pane (L3/L4) for GitLab accounts. Composes the header,
/// feature tab strip, and project scope list.
class GitlabNavPane extends ConsumerWidget {
  const GitlabNavPane({
    super.key,
    required this.account,
    required this.location,
    required this.sections,
    this.onWebUrlTap,
  });

  final Account account;
  final ToolLocation location;
  final List<ToolSection> sections;
  final VoidCallback? onWebUrlTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ToolPaneScaffold(
      header: ToolPaneHeader(account: account, onWebUrlTap: onWebUrlTap),
      tabStrip: FeatureTabStrip(
        sections: sections,
        selectedSectionId: location.section,
        onSectionSelected: (section) => ref
            .read(appNavProvider.notifier)
            .selectSection(section, sections: sections),
      ),
      body: GitlabProjectsScopeList(account: account, location: location),
    );
  }
}

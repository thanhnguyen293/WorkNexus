import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../shared/shell_pane/feature_tab_strip.dart';
import '../../../../shared/shell_pane/tool_pane_scaffold.dart';
import 'zentao_scope_lists.dart';

/// Navigation pane (L3/L4) for ZenTao accounts. Composes the header,
/// feature tab strip, and scope lists.
class ZentaoNavPane extends ConsumerWidget {
  const ZentaoNavPane({
    super.key,
    required this.account,
    required this.location,
    required this.sections,
  });

  final Account account;
  final ToolLocation location;
  final List<ToolSection> sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget body;
    switch (location.section.value) {
      case 'zentao.tasks':
        body = ZentaoProjectsScopeList(account: account, location: location);
      case 'zentao.bugs':
        body = ZentaoProductsScopeList(account: account, location: location);
      default:
        body = const SizedBox.shrink();
    }

    return ToolPaneScaffold(
      tabStrip: FeatureTabStrip(
        sections: sections,
        selectedSectionId: location.section,
        onSectionSelected: (id) => ref
            .read(appNavProvider.notifier)
            .selectSection(id, sections: sections),
      ),
      body: body,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../shared/shell_pane/tool_pane_scaffold.dart';
import 'zentao_account_switcher.dart';
import 'zentao_bug_module_pane.dart';
import 'zentao_task_module_pane.dart';

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
        body = ZentaoTaskModulePane(account: account);
      case 'zentao.bugs':
        body = ZentaoBugModulePane(account: account, location: location);
      default:
        body = const SizedBox.shrink();
    }

    return ToolPaneScaffold(
      // Tasks and Bugs are rail places of their own; the pane picks the
      // account instead.
      tabStrip: ZenTaoAccountSwitcher(
        account: account,
        section: location.section,
        sections: sections,
      ),
      body: body,
    );
  }
}

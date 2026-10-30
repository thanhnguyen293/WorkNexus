import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/coming_soon_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shell_pane/feature_tab_strip.dart';
import '../../../../shared/shell_pane/tool_pane_scaffold.dart';
import 'zentao_scope_lists.dart';

/// Builds the chat list shown in the ZenTao pane, narrowed (no search or
/// filter tabs) when [compact].
typedef ChatPaneBuilder = Widget Function(BuildContext context, bool compact);

/// Navigation pane (L3/L4) for ZenTao accounts. Composes the header,
/// feature tab strip, and scope lists.
class ZentaoNavPane extends ConsumerWidget {
  const ZentaoNavPane({
    super.key,
    required this.account,
    required this.location,
    required this.sections,
    this.chatPane,
    this.chatMessagesMinWidth = 0,
  });

  final Account account;
  final ToolLocation location;
  final List<ToolSection> sections;
  final ChatPaneBuilder? chatPane;

  /// Narrowest the chat's message column may get: in a window too narrow
  /// for it beside the full pane, the pane narrows (on every section).
  final double chatMessagesMinWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final sizes = context.sizes;
    final chatPane = this.chatPane;
    // The chat would squeeze its messages a few letters per line. Every
    // section narrows alike, so the pane and its tabs keep one size as the
    // user moves between them.
    final compact =
        chatPane != null &&
        MediaQuery.sizeOf(context).width -
                sizes.railWidth -
                sizes.toolPaneWidth <
            chatMessagesMinWidth;

    final Widget body;
    switch (location.section.value) {
      case 'zentao.tasks':
        body = ZentaoProjectsScopeList(account: account, location: location);
      case 'zentao.bugs':
        body = ZentaoProductsScopeList(account: account, location: location);
      case 'zentao.chat':
        body =
            chatPane?.call(context, compact) ??
            ComingSoonView(
              icon: LucideIcons.messageSquare300,
              title: l.chat,
              body: '',
            );
      default:
        body = const SizedBox.shrink();
    }

    return ToolPaneScaffold(
      // Narrower, its section tabs still side by side.
      width: compact ? sizes.toolPaneCompactWidth : null,
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

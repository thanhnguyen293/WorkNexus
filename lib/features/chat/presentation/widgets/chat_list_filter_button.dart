import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_category_providers.dart';
import 'chat_list_filter_panel.dart';

/// A filter icon beside the chat list's tabs: opens the filter by status
/// (all / unread) and by category tags. An icon rather than a labelled
/// dropdown, so it leaves the tabs their room; while it narrows the list it
/// is tinted and carries a dot.
class ChatListFilterButton extends ConsumerWidget {
  const ChatListFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrowed = ref.watch(chatListFilterProvider).isNarrowed;
    return MenuAnchor(
      style: appMenuAnchorStyle,
      alignmentOffset: Offset(0, context.spacing.xs),
      menuChildren: [
        Builder(
          builder: (context) => ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: context.sizes.toolPaneWidth,
              maxWidth: context.sizes.toolPaneWidth,
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ChatListFilterPanel(
              onClose: () => MenuController.maybeOf(context)?.close(),
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          AppIconButton(
            icon: LucideIcons.listFilter300,
            size: AppIconButtonSize.small,
            tooltip: AppL10n.of(context).chatCategorize,
            selected: narrowed || controller.isOpen,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
          if (narrowed) const Positioned(top: 0, right: 0, child: _Dot()),
        ],
      ),
    );
  }
}

/// The "filter on" mark: an accent dot ringed in the pane's colour so it
/// reads on the tinted button.
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = context.spacing.md;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          border: Border.all(color: c.surface, width: context.borders.thick),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';

import 'zentao_doc_history_panel.dart';

/// The toolbar's history button: the document's history in a popover under
/// it, closed by a tap outside it (or Escape), like the outline's.
class ZenTaoDocHistoryButton extends StatelessWidget {
  const ZenTaoDocHistoryButton({
    super.key,
    required this.account,
    required this.docId,
  });

  final Account account;
  final String docId;

  @override
  Widget build(BuildContext context) {
    final sizes = context.sizes;
    return MenuAnchor(
      style: appMenuAnchorStyle,
      alignmentOffset: Offset(0, context.spacing.xs),
      menuChildren: [
        Builder(
          // Clear of the window's right edge.
          builder: (context) => Padding(
            padding: EdgeInsets.only(right: context.spacing.xl),
            child: ConstrainedBox(
              // As tall as its entries, up to most of the window's height
              // (a long history scrolls inside).
              constraints: BoxConstraints(
                // Wide enough for a diff's lines of code.
                maxWidth: sizes.dialogMd,
                minWidth: sizes.dialogMd,
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: ZenTaoDocHistoryPanel(
                account: account,
                docId: docId,
                onClose: () => MenuController.maybeOf(context)?.close(),
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => AppIconButton(
        icon: LucideIcons.history300,
        tooltip: AppL10n.of(context).docsHistory,
        selected: controller.isOpen,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

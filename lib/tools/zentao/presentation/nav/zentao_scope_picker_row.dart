import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../shared/shell_pane/scope_rows.dart';

/// The last row of the side panel's products / executions: opens the
/// header's picker ([popover]) beside the panel, so a product or execution
/// that is not pinned is a pick away here too.
class ZenTaoScopePickerRow extends StatefulWidget {
  const ZenTaoScopePickerRow({
    super.key,
    required this.label,
    required this.popover,
  });

  final String label;

  /// Builds the picker; it calls the given callback once a pick is made.
  final Widget Function(VoidCallback close) popover;

  @override
  State<ZenTaoScopePickerRow> createState() => _ZenTaoScopePickerRowState();
}

class _ZenTaoScopePickerRowState extends State<ZenTaoScopePickerRow> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    alignmentOffset: const Offset(0, 4),
    menuChildren: [widget.popover(_menu.close)],
    builder: (context, controller, _) => ScopeRow(
      name: widget.label,
      icon: LucideIcons.search300,
      onTap: () => controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

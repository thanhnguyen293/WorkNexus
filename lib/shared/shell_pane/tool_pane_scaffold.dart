import 'package:flutter/material.dart';

import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';

/// The 300px column hosting a tool's navigation pane (L3/L4).
/// Composed of an optional [tabStrip] and a scrollable [body].
class ToolPaneScaffold extends StatelessWidget {
  const ToolPaneScaffold({super.key, this.tabStrip, required this.body});

  final Widget? tabStrip;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tabStrip = this.tabStrip;

    return SizedBox(
      width: context.sizes.toolPaneWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(right: context.hairlineSide),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?tabStrip,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

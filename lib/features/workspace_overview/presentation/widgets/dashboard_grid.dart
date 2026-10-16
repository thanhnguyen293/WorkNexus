import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Dashboard cards two per row when [wide] — the cards of a row share the
/// taller one's height — else one column. An odd last card takes the full
/// width.
class DashboardGrid extends StatelessWidget {
  const DashboardGrid({super.key, required this.wide, required this.cells});

  final bool wide;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final rows = <Widget>[
      if (!wide)
        ...cells
      else
        for (var i = 0; i < cells.length; i += 2)
          if (i + 1 < cells.length)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cells[i]),
                  SizedBox(width: s.xl),
                  Expanded(child: cells[i + 1]),
                ],
              ),
            )
          else
            cells[i],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) SizedBox(height: s.xl),
          row,
        ],
      ],
    );
  }
}

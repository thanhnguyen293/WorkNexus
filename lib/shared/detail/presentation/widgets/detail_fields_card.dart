import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import 'detail_field_rows.dart';
import 'detail_region_card.dart';
import 'section_label.dart';

/// Width of a sidebar field table's label column.
const double kSidebarLabelWidth = 100;

/// A sidebar region's inset: the regular gutter, a little less at the foot
/// since the last row's hairline already closes it.
EdgeInsets detailSidebarInset(BuildContext context) => EdgeInsets.fromLTRB(
  context.spacing.lg,
  context.spacing.lg,
  context.spacing.lg,
  context.spacing.md,
);

/// A ZenTao ticket's metadata group in the detail sidebar: a section label
/// over a key/value table with the values right-aligned, then [children]
/// (e.g. an empty-fields toggle).
class DetailFieldsCard extends StatelessWidget {
  const DetailFieldsCard({
    super.key,
    required this.title,
    required this.rows,
    this.valueWidgets = const {},
    this.children = const [],
  });

  final String title;
  final List<(String, String)> rows;

  /// Values drawn as a widget (a chip, a link) instead of text, by row label.
  final Map<String, Widget> valueWidgets;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DetailRegionCard(
      padding: detailSidebarInset(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title),
          SizedBox(height: context.spacing.xs),
          DetailFieldRows(
            rows: rows,
            labelWidth: kSidebarLabelWidth,
            alignEnd: true,
            valueWidgets: valueWidgets,
          ),
          ...children,
        ],
      ),
    );
  }
}

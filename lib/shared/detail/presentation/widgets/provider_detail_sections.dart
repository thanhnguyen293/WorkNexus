import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import 'detail_field_rows.dart';
import 'detail_region_card.dart';
import 'section_label.dart';

/// GitLab/GitHub raw merge states are snake_case tokens (`need_rebase`,
/// `ci_still_running`, `behind`, `clean`, …); show them as readable words.
String humanizeMergeState(String? raw) {
  final words = (raw ?? '').replaceAll('_', ' ').trim();
  return words.isEmpty ? '' : '${words[0].toUpperCase()}${words.substring(1)}';
}

/// The metadata card shared by the detail sidebars — a labeled
/// section over a hairline key/value table, with empty rows filtered out.
class DetailMetaCard extends StatelessWidget {
  const DetailMetaCard({
    super.key,
    required this.title,
    required this.rows,
    this.valueWidgets = const {},
  });

  final String title;
  final List<(String, String)> rows;

  /// Values drawn as a widget instead of text (see [DetailFieldRows]).
  final Map<String, Widget> valueWidgets;

  @override
  Widget build(BuildContext context) {
    final filled = rows.where((r) => r.$2.trim().isNotEmpty).toList();
    if (filled.isEmpty) return const SizedBox.shrink();
    return DetailRegionCard(
      padding: EdgeInsets.fromLTRB(
        context.spacing.lg,
        context.spacing.lg,
        context.spacing.lg,
        context.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title),
          SizedBox(height: context.spacing.xs),
          DetailFieldRows(
            rows: filled,
            labelWidth: 100,
            alignEnd: true,
            valueWidgets: valueWidgets,
          ),
        ],
      ),
    );
  }
}

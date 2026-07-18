import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'section_label.dart';

/// A labeled group of key/value rows (e.g. "Classification", "Lifecycle").
/// Renders nothing when [rows] is empty so callers can pass raw candidate
/// lists and let the section disappear if none survive filtering.
class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        SizedBox(height: context.spacing.xs),
        DetailFieldRows(rows: rows),
      ],
    );
  }
}

/// A borderless-hairline key/value table. The label column is fixed-width so
/// values align across rows; empty rows should be filtered by the caller.
class DetailFieldRows extends StatelessWidget {
  const DetailFieldRows({
    super.key,
    required this.rows,
    this.labelWidth = 120,
    this.alignEnd = false,
  });

  final List<(String, String)> rows;
  final double labelWidth;

  /// Right-aligns the value column (metadata-sidebar style) instead of the
  /// default left alignment.
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (final row in rows)
          Container(
            padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    row.$1,
                    style: context.typography.meta.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    textAlign: alignEnd ? TextAlign.right : TextAlign.start,
                    style: context.typography.secondary.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

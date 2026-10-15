import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_count_badge.dart';

/// The heading over a main-column section of a two-pane detail (Activity,
/// Commits, Changed files), with an optional item [count].
class DetailSectionTitle extends StatelessWidget {
  const DetailSectionTitle(this.title, {super.key, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.lg),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.titleSm.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (count != null && count > 0) ...[
            SizedBox(width: context.spacing.sm),
            AppCountBadge(count),
          ],
        ],
      ),
    );
  }
}

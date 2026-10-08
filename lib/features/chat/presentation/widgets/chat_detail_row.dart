import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// One labelled detail; the value can be selected and copied.
class ChatDetailRow extends StatelessWidget {
  const ChatDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.spaced = true,
  });

  /// Keeps a gap above it (stacked rows in a dialog); false where the
  /// container spaces the rows itself.
  final bool spaced;

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(top: spaced ? s.xl : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: s.xl4, color: c.textSecondary),
          SizedBox(width: s.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.typography.caption.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                SelectableText(
                  value,
                  style: context.typography.body.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(top: s.xl),
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

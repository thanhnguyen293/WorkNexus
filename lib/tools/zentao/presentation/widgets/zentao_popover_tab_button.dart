import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Reusable tab button (e.g. 'Mine' vs 'Others') in ZenTao popover cards.
class ZenTaoPopoverTabButton extends StatelessWidget {
  const ZenTaoPopoverTabButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? c.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: context.typography.bodySmStrong.copyWith(
            color: active ? c.accent : c.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

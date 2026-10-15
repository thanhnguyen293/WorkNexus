import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

/// Semantic status pill for ZenTao work items (Doing, Done, Verify, Paused, Waiting).
class ZenTaoStatusPill extends StatelessWidget {
  const ZenTaoStatusPill({
    super.key,
    required this.status,
    required this.providerStatus,
  });

  final UnifiedStatus status;
  final String providerStatus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (status) {
      UnifiedStatus.inprogress => ('Doing', c.accent),
      UnifiedStatus.done => ('Done', c.success),
      UnifiedStatus.review => ('Verify', c.accent),
      UnifiedStatus.blocked => ('Paused', c.warning),
      _ => (
        providerStatus.isNotEmpty ? providerStatus : 'Waiting',
        c.textTertiary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.radii.xs),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.typography.monoXs.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

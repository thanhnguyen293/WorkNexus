import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

/// Small square workspace badge with its chosen icon, falling back to initials.
class WorkspaceBadge extends StatelessWidget {
  const WorkspaceBadge(
    this.color,
    this.short, {
    super.key,
    this.big = false,
    this.iconKey,
  });

  final Color color;
  final String short;
  final bool big;
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    final s = big ? 18.0 : 16.0;
    final icon = workspaceIconData(iconKey);
    return Container(
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.radii.xs),
      ),
      child: icon == null
          ? Text(
              short,
              style:
                  (big ? context.typography.badgeLg : context.typography.badge)
                      .copyWith(color: context.colors.onColorInk),
            )
          : Icon(icon, size: big ? 12 : 10, color: context.colors.onColorInk),
    );
  }
}

const workspaceIconKeys = <String>[
  'briefcase',
  'home',
  'building',
  'rocket',
  'code',
  'storage',
];

IconData? workspaceIconData(String? key) => switch (key) {
  'briefcase' => Icons.work_outline,
  'home' => Icons.home_outlined,
  'building' => Icons.apartment,
  'rocket' => Icons.rocket_launch_outlined,
  'code' => Icons.code,
  'storage' => Icons.storage_outlined,
  _ => null,
};

const workspaceColorChoices = <int>[
  0xFF16A99C,
  0xFFCF8A3A,
  0xFF8F63D6,
  0xFF3B82F6,
  0xFFE05561,
  0xFF2F8A52,
  0xFFDC2626,
  0xFF0891B2,
];

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// `1.2.0 → v1.3.0`, as two pills so the new version stands out.
class UpdateVersionChange extends StatelessWidget {
  const UpdateVersionChange({super.key, required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(text: _plain(from), color: c.textSecondary),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
          child: Icon(
            LucideIcons.arrowRight300,
            size: context.sizes.iconMd,
            color: c.textTertiary,
          ),
        ),
        _Pill(text: _plain(to), color: c.accent, strong: true),
      ],
    );
  }

  static String _plain(String version) =>
      version.startsWith('v') ? version : 'v$version';
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.strong = false});

  final String text;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.xl),
        border: Border.all(color: strong ? color : c.border),
      ),
      child: Text(
        text,
        style: context.typography.captionStrong.copyWith(color: color),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A group of editor fields in the app's panel-card style: a surface with a
/// hairline border under an icon and title, like the dashboard's cards.
class EditorSection extends StatelessWidget {
  const EditorSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      margin: EdgeInsets.only(bottom: s.xl),
      padding: EdgeInsets.fromLTRB(s.xl, s.lg, s.xl, s.xxs),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.fromBorderSide(context.hairlineSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: s.xl2, color: c.textSecondary),
              SizedBox(width: s.md),
              Expanded(
                child: Text(
                  title,
                  style: context.typography.bodySmStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: s.lg),
          ...children,
        ],
      ),
    );
  }
}

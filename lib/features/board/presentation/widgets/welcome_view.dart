import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// The launch/home screen shown before any source is selected. Deliberately
/// minimal: an app glyph, the title, and a hint to pick a source from the
/// sidebar. No toolbar and no board — those appear once a view is opened.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radii.lg),
              border: Border.all(
                color: c.borderStrong,
                width: context.borders.medium,
              ),
            ),
            child: Icon(
              Icons.space_dashboard_outlined,
              size: 24,
              color: c.textTertiary,
            ),
          ),
          SizedBox(height: context.spacing.xl),
          Text(
            l.welcomeTitle,
            style: context.typography.titleSm.copyWith(color: c.textPrimary),
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            l.welcomeHint,
            style: context.typography.secondary.copyWith(
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

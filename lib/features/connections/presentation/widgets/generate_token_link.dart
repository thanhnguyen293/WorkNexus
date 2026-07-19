import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// A subtle "Generate token" link shown beside a connection dialog's PAT field
/// label; [onTap] opens the provider's token-creation page in the browser.
/// Shared by the GitHub and GitLab connection dialogs.
class GenerateTokenLink extends StatelessWidget {
  const GenerateTokenLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.xs,
          vertical: context.spacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new, size: 12, color: c.accent),
            SizedBox(width: context.spacing.xxs),
            Text(
              l.generateToken,
              style: context.typography.captionStrong.copyWith(color: c.accent),
            ),
          ],
        ),
      ),
    );
  }
}

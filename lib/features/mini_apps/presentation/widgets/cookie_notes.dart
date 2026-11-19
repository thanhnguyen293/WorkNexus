import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';

/// A line of guidance in the cookie import dialog; red for an [error].
class CookieNote extends StatelessWidget {
  const CookieNote(this.text, {super.key, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      style: context.typography.caption.copyWith(
        color: error ? c.error : c.textSecondary,
      ),
    );
  }
}

/// Why something in the cookie import failed, and the way past it: trying
/// again, or (for Safari) the Privacy settings.
class CookieErrorNote extends StatelessWidget {
  const CookieErrorNote({
    super.key,
    required this.message,
    required this.onRetry,
    this.onOpenPrivacy,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final openPrivacy = onOpenPrivacy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: context.spacing.md,
      children: [
        CookieNote(message, error: true),
        Row(
          spacing: context.spacing.md,
          children: [
            if (openPrivacy != null)
              AppButton.outlinedNeutral(
                size: AppButtonSize.small,
                icon: LucideIcons.shieldCheck300,
                onPressed: openPrivacy,
                child: Text(l.miniAppCookiesOpenPrivacy),
              ),
            AppButton.outlinedNeutral(
              size: AppButtonSize.small,
              icon: LucideIcons.refreshCw300,
              onPressed: onRetry,
              child: Text(l.miniAppCookiesRetry),
            ),
          ],
        ),
      ],
    );
  }
}

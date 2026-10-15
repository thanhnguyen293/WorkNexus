import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';

/// Covers a mini app whose page could not load: what went wrong and a way to
/// try again.
class MiniAppLoadError extends StatelessWidget {
  const MiniAppLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return ColoredBox(
      color: c.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: s.md,
          children: [
            Text(
              l.miniAppLoadFailed,
              style: context.typography.body.copyWith(color: c.textPrimary),
            ),
            Text(
              message,
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
            AppButton.filled(onPressed: onRetry, child: Text(l.miniAppRetry)),
          ],
        ),
      ),
    );
  }
}

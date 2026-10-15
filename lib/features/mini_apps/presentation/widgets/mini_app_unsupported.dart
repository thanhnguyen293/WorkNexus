import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';

/// Stands in for the page where the system has no web view to embed (Linux):
/// the way out is the browser.
class MiniAppUnsupported extends StatelessWidget {
  const MiniAppUnsupported({super.key, required this.onOpenExternal});

  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: s.xl,
        children: [
          Text(
            l.miniAppUnsupported,
            style: context.typography.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          AppButton.filled(
            onPressed: onOpenExternal,
            child: Text(l.miniAppOpenInBrowser),
          ),
        ],
      ),
    );
  }
}

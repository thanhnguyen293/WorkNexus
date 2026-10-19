import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';

/// The top bar of a mini app's pop-up window: back and forward through the
/// pages it has been to, its title, a button that opens its page in the
/// browser, and close. [onBack], [onForward] and [onOpenExternal] are null
/// while there is nothing to go to (the button then shows as disabled).
class MiniAppPopupHeader extends StatelessWidget {
  const MiniAppPopupHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.onBack,
    this.onForward,
    this.onOpenExternal,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final VoidCallback? onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xs),
      child: Row(
        spacing: s.xs,
        children: [
          AppIconButton(
            icon: LucideIcons.arrowLeft300,
            tooltip: l.miniAppBack,
            onPressed: onBack,
          ),
          AppIconButton(
            icon: LucideIcons.arrowRight300,
            tooltip: l.miniAppForward,
            onPressed: onForward,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: s.md),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
          AppIconButton(
            icon: LucideIcons.externalLink300,
            tooltip: l.miniAppOpenInBrowser,
            onPressed: onOpenExternal,
          ),
          AppIconButton(
            icon: LucideIcons.x300,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

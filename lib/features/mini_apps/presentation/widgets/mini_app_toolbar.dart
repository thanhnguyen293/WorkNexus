import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../l10n/app_localizations.dart';

/// A mini app's browser-style bar: back, forward, reload / stop, the address
/// of the page (type another and press Enter to go there) and "open in the
/// browser". Without a web view (no [onBack] and the rest) only the address
/// and the browser button remain.
class MiniAppToolbar extends StatelessWidget {
  const MiniAppToolbar({
    super.key,
    required this.address,
    required this.addressFocus,
    required this.onSubmitted,
    required this.onOpenExternal,
    this.loading = false,
    this.onBack,
    this.onForward,
    this.onReload,
    this.onStop,
    this.onDevTools,
    this.showNavigation = true,
  });

  final TextEditingController address;
  final FocusNode addressFocus;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onOpenExternal;

  /// The page is still loading: reload becomes stop.
  final bool loading;

  /// Null while there is no page to go back / forward to.
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final VoidCallback? onReload;
  final VoidCallback? onStop;

  /// Opens the page's developer tools; null hides the button.
  final VoidCallback? onDevTools;
  final bool showNavigation;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.xs),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Row(
        spacing: s.xs,
        children: [
          if (showNavigation) ...[
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
            AppIconButton(
              icon: loading ? LucideIcons.x300 : LucideIcons.refreshCw300,
              tooltip: loading ? l.miniAppStop : l.miniAppReload,
              onPressed: loading ? onStop : onReload,
            ),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: s.sm),
              child: TextField(
                controller: address,
                focusNode: addressFocus,
                onSubmitted: onSubmitted,
                style: context.typography.bodySm.copyWith(color: c.textPrimary),
                decoration: appInputDecoration(context, hint: l.miniAppUrlHint),
              ),
            ),
          ),
          if (onDevTools != null)
            AppIconButton(
              icon: LucideIcons.bug300,
              tooltip: l.miniAppDevTools,
              onPressed: onDevTools,
            ),
          AppIconButton(
            icon: LucideIcons.externalLink300,
            tooltip: l.miniAppOpenInBrowser,
            onPressed: onOpenExternal,
          ),
        ],
      ),
    );
  }
}

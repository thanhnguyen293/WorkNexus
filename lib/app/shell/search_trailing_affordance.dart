import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/platform/desktop_window_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hover_surface.dart';

/// Trailing clear icon or keyboard shortcut badge for [ContextualSearchField].
class SearchTrailingAffordance extends StatelessWidget {
  const SearchTrailingAffordance({
    super.key,
    required this.hasText,
    required this.onClear,
  });

  final bool hasText;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;

    if (hasText) {
      return HoverSurface(
        onTap: onClear,
        borderRadius: BorderRadius.circular(r.xs),
        padding: EdgeInsets.all(s.xxs),
        child: Icon(
          LucideIcons.x300,
          size: context.sizes.iconXs,
          color: c.textTertiary,
        ),
      );
    }

    final isMac = DesktopWindowService.isMacOS;
    final shortcutLabel = isMac ? '⌘K' : 'Ctrl K';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.none),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(r.xs),
        border: Border.all(color: c.border),
      ),
      child: Text(
        shortcutLabel,
        style: context.typography.monoXs.copyWith(color: c.textTertiary),
      ),
    );
  }
}

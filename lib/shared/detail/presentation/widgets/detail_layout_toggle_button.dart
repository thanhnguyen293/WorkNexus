import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// Picks the detail panel's layout as a two-segment icon control, like the
/// view switch of a tool: both layouts in sight, the current one raised. The
/// icons draw the layout itself — content beside a right-hand pane, or one
/// centred column between empty margins.
class DetailLayoutToggleButton extends ConsumerWidget {
  const DetailLayoutToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final layout = ref.watch(appSettingsProvider.select((s) => s.detailLayout));
    void pick(DetailLayout next) {
      if (next != layout) {
        ref.read(appSettingsProvider.notifier).setDetailLayout(next);
      }
    }

    return Container(
      key: const ValueKey<String>('detail-layout-toggle'),
      height: context.sizes.controlMd,
      padding: EdgeInsets.all(context.spacing.xxs),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: context.cardBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LayoutSegment(
            icon: LucideIcons.panelRight300,
            label: l.layoutTwoPane,
            selected: layout == DetailLayout.twoPane,
            onTap: () => pick(DetailLayout.twoPane),
          ),
          _LayoutSegment(
            icon: LucideIcons.panelLeftRightDashed300,
            label: l.layoutDocument,
            selected: layout == DetailLayout.document,
            onTap: () => pick(DetailLayout.document),
          ),
        ],
      ),
    );
  }
}

class _LayoutSegment extends StatelessWidget {
  const _LayoutSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      child: HoverSurface(
        onTap: onTap,
        selected: selected,
        semanticLabel: label,
        width: context.sizes.controlMd - context.spacing.xxs * 2,
        alignment: Alignment.center,
        color: selected ? c.surface : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.sm),
        border: selected ? context.cardBorder : null,
        child: Icon(
          icon,
          size: context.sizes.iconMd,
          color: selected ? c.textPrimary : c.textTertiary,
        ),
      ),
    );
  }
}

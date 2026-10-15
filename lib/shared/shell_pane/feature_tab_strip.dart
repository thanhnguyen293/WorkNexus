import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/tools/tool_module.dart';
import '../../core/widgets/hover_surface.dart';
import '../../core/widgets/unread_badge.dart';
import '../../l10n/app_localizations.dart';

/// A horizontal tab strip for switching between a tool's sections (L3 features).
/// Displays icon-over-label tabs with optional reactive unread badges.
class FeatureTabStrip extends StatelessWidget {
  const FeatureTabStrip({
    super.key,
    required this.sections,
    required this.selectedSectionId,
    required this.onSectionSelected,
  });

  final List<ToolSection> sections;
  final SectionId selectedSectionId;
  final ValueChanged<SectionId> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: Border(bottom: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xxs),
      child: Row(
        children: [
          for (final section in sections)
            Expanded(
              child: FeatureTabItem(
                section: section,
                selected: section.id == selectedSectionId,
                onTap: () => onSectionSelected(section.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// An individual tab in the [FeatureTabStrip].
class FeatureTabItem extends ConsumerWidget {
  const FeatureTabItem({
    super.key,
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final ToolSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    final unreadProvider = section.unreadCount;
    final unreadCount = unreadProvider != null ? ref.watch(unreadProvider) : 0;

    final inkColor = selected ? c.accent : c.textSecondary;
    final labelText = section.label(l);

    return Tooltip(
      message: labelText,
      child: HoverSurface(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(context.radii.sm),
        color: selected ? c.surface : Colors.transparent,
        padding: EdgeInsets.symmetric(vertical: s.xs, horizontal: s.xxs),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(section.icon, size: context.sizes.iconSm, color: inkColor),
                SizedBox(height: s.xxs),
                Text(
                  labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.captionSm.copyWith(
                    color: inkColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (unreadCount > 0)
              Positioned(
                top: -s.xxs,
                right: s.xs,
                child: UnreadBadge(count: unreadCount),
              ),
          ],
        ),
      ),
    );
  }
}

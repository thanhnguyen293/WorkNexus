import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../tools/tool_module.dart';
import 'hover_surface.dart';

/// A segmented tab bar for switching between view modes (List, Kanban, Board, Calendar, etc.)
/// within a tool section header.
///
/// Supports keyboard navigation via arrow keys (Left/Right) and Enter/Space activation.
class ViewModeTabBar extends StatelessWidget {
  const ViewModeTabBar({
    super.key,
    required this.modes,
    required this.selectedModeId,
    required this.onModeSelected,
    this.focusNode,
    this.autofocus = false,
  });

  final List<ToolViewMode> modes;
  final ViewModeId? selectedModeId;
  final ValueChanged<ViewModeId> onModeSelected;
  final FocusNode? focusNode;
  final bool autofocus;

  void _handleArrowKey(int delta) {
    if (modes.isEmpty) return;
    final currentIndex = modes.indexWhere((m) => m.id == selectedModeId);
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + delta).clamp(0, modes.length - 1);
    if (nextIndex != currentIndex) {
      onModeSelected(modes[nextIndex].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (modes.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final radii = context.radii;
    final spacing = context.spacing;
    final sizes = context.sizes;

    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _handleArrowKey(1);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _handleArrowKey(-1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        height: sizes.controlMd,
        padding: EdgeInsets.all(spacing.xxs),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(radii.md),
          border: context.cardBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in modes)
              _ViewModeSegment(
                mode: mode,
                selected: mode.id == selectedModeId,
                onTap: () => onModeSelected(mode.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewModeSegment extends StatelessWidget {
  const _ViewModeSegment({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ToolViewMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radii = context.radii;
    final spacing = context.spacing;
    final sizes = context.sizes;
    final typography = context.typography;

    final l10n = Localizations.of<AppL10n>(context, AppL10n);
    final label = l10n != null ? mode.label(l10n) : mode.id.value;

    return HoverSurface(
      onTap: onTap,
      selected: selected,
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      alignment: Alignment.center,
      color: selected ? colors.surface : colors.surfaceSubtle,
      borderRadius: BorderRadius.circular(radii.sm),
      border: selected ? context.cardBorder : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mode.icon,
            size: sizes.iconSm,
            color: selected ? colors.textPrimary : colors.textSecondary,
          ),
          SizedBox(width: spacing.xs),
          Text(
            label,
            style: typography.bodySm.copyWith(
              color: selected ? colors.textPrimary : colors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hover_surface.dart';
import '../../l10n/app_localizations.dart';

/// The top workspace button in the navigation rail (design §8, specs S3.1).
/// Selects the workspace-level view (Overview, Integrations, Members, Settings).
class RailWorkspaceButton extends ConsumerWidget {
  const RailWorkspaceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;
    final l = AppL10n.of(context);
    final nav = ref.watch(appNavProvider);

    final isSelected = nav.rail is WorkspaceTarget;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Tooltip(
        message: l.workspace,
        preferBelow: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: s.xxs),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              HoverSurface(
                key: const ValueKey('rail-workspace-button'),
                onTap: () {
                  ref
                      .read(appNavProvider.notifier)
                      .selectWorkspaceSection(WorkspaceSection.overview);
                },
                selected: isSelected,
                borderRadius: BorderRadius.circular(r.md),
                color: isSelected ? c.selectionFill : Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xs),
                child: SizedBox(
                  width: context.sizes.railWidth - s.xl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: context.sizes.railButton,
                        height: context.sizes.railButton,
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.layoutGrid300,
                          size: context.sizes.iconLg,
                          color: isSelected ? c.accent : c.textSecondary,
                        ),
                      ),
                      SizedBox(height: s.xxs),
                      Text(
                        l.workspace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.typography.captionSm.copyWith(
                          color: isSelected ? c.accent : c.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  left: 0,
                  child: Container(
                    width: 3,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(r.xs),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

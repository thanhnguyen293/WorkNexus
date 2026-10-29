import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/overview_providers.dart';

/// Navigation pane (L3) for workspace-level sections:
/// Overview, Integrations, Members, and Settings (design §5).
class WorkspaceNavPane extends ConsumerWidget {
  const WorkspaceNavPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final activeWs = ref.watch(activeWorkspaceProvider);
    final nav = ref.watch(appNavProvider);
    final accounts = ref.watch(workspaceAccountsProvider);
    final wsName = activeWs?.name ?? '';

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: context.hairlineSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WorkspaceHeader(workspaceName: wsName),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
            child: Column(
              children: [
                _WorkspaceNavRow(
                  label: l.overview,
                  icon: LucideIcons.layoutDashboard300,
                  selected: nav.workspaceSection == WorkspaceSection.overview,
                  onTap: () => ref
                      .read(appNavProvider.notifier)
                      .selectWorkspaceSection(WorkspaceSection.overview),
                ),
                SizedBox(height: s.xxs),
                _WorkspaceNavRow(
                  label: l.integrations,
                  icon: LucideIcons.plug300,
                  count: accounts.length,
                  selected:
                      nav.workspaceSection == WorkspaceSection.integrations,
                  onTap: () => ref
                      .read(appNavProvider.notifier)
                      .selectWorkspaceSection(WorkspaceSection.integrations),
                ),
                // Members stays out of the menu until the feature exists:
                // for now its page only says it is coming.
                SizedBox(height: s.xxs),
                _WorkspaceNavRow(
                  label: l.settings,
                  icon: LucideIcons.settings300,
                  selected: nav.workspaceSection == WorkspaceSection.settings,
                  onTap: () => ref
                      .read(appNavProvider.notifier)
                      .selectWorkspaceSection(WorkspaceSection.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.workspaceName});

  final String workspaceName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final headerText = 'WORKSPACE / $workspaceName'.toUpperCase();

    return Container(
      height: context.sizes.titleBarHeight,
      padding: EdgeInsets.symmetric(horizontal: s.lg),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Text(
        headerText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.typography.labelWide.copyWith(
          color: c.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WorkspaceNavRow extends StatelessWidget {
  const _WorkspaceNavRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final ink = selected ? c.accent : c.textPrimary;

    return HoverSurface(
      onTap: onTap,
      selected: selected,
      borderRadius: BorderRadius.circular(context.radii.sm),
      color: selected ? c.selectionFill : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
      height: context.sizes.controlSm,
      child: Row(
        children: [
          Icon(
            icon,
            size: context.sizes.iconSm,
            color: selected ? c.accent : c.textTertiary,
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodySm.copyWith(
                color: ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (count != null) ...[
            SizedBox(width: s.xs),
            _CountBadge(count: count!, selected: selected),
          ],
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.none),
      decoration: BoxDecoration(
        color: selected ? c.accent.withValues(alpha: 0.15) : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Text(
        '$count',
        style: context.typography.captionSm.copyWith(
          color: selected ? c.accent : c.textTertiary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

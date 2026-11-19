import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hover_surface.dart';
import '../../features/panic_switch/presentation/providers/panic_switch_providers.dart';
import '../../features/workspace_overview/presentation/providers/overview_providers.dart';
import '../../l10n/app_localizations.dart';

/// The Settings place's column beside the rail: a page per group of the
/// app's settings, then the connected accounts with how many there are.
class SettingsNavPane extends ConsumerWidget {
  const SettingsNavPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final current = ref.watch(appNavProvider.select((n) => n.settingsSection));
    final panicSwitch = ref.watch(panicSwitchAccountProvider) != null;
    final accounts = ref.watch(workspaceAccountsProvider);
    final nav = ref.read(appNavProvider.notifier);

    return Container(
      width: context.sizes.toolPaneWidth,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: context.hairlineSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PaneHeader(title: l.settings),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
            child: Column(
              spacing: s.xxs,
              children: [
                for (final (section, label, icon) in [
                  (
                    SettingsSection.general,
                    l.settingsGeneral,
                    LucideIcons.slidersHorizontal300,
                  ),
                  (
                    SettingsSection.translation,
                    l.translationSection,
                    LucideIcons.languages300,
                  ),
                  (
                    SettingsSection.miniApps,
                    l.miniAppSettingsTitle,
                    LucideIcons.appWindow300,
                  ),
                  // Only for users of the ZenTao the feature is offered for.
                  if (panicSwitch)
                    (
                      SettingsSection.panicSwitch,
                      l.panicSwitchTitle,
                      LucideIcons.siren300,
                    ),
                ])
                  _SettingsNavRow(
                    label: label,
                    icon: icon,
                    selected: section == current,
                    onTap: () => nav.selectSettings(section),
                  ),
                _SettingsNavRow(
                  label: l.integrations,
                  icon: LucideIcons.plug300,
                  count: accounts.length,
                  selected: current == SettingsSection.integrations,
                  onTap: () => nav.selectSettings(SettingsSection.integrations),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    return Container(
      height: context.sizes.titleBarHeight,
      padding: EdgeInsets.symmetric(horizontal: s.lg),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Text(
        title.toUpperCase(),
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

class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({
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

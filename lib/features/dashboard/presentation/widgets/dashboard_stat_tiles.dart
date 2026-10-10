import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_dashboard.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';

/// The overview's counters: open bugs and tasks (which open their full
/// lists), and the stories and sprints the user is in. Each says one more
/// thing worth knowing — how many are urgent, in progress or running.
class DashboardStatTiles extends ConsumerWidget {
  const DashboardStatTiles({
    super.key,
    required this.account,
    required this.dashboard,
  });

  final Account account;
  final ZenTaoDashboard? dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final queue = ref.watch(workQueueProvider(account));
    final tickets = [...queue.queue.inProgress, ...queue.queue.notStarted];
    bool isBug(String? type) => type?.toLowerCase() == 'bug';
    final urgentBugs = tickets
        .where(
          (t) =>
              isBug(t.externalType) && t.priority.level <= Priority.high.level,
        )
        .length;
    final doingTasks = tickets
        .where(
          (t) => !isBug(t.externalType) && t.status == UnifiedStatus.inprogress,
        )
        .length;
    final d = dashboard;
    final running = d?.executions.where((e) => e.status == 'doing').length ?? 0;
    void open(DashboardItemKind kind) =>
        ref.read(dashboardWorkKindProvider.notifier).state = kind;
    final tiles = [
      _Tile(
        icon: LucideIcons.bug500,
        color: c.error,
        value: queue.openBugs,
        label: l.dashboardStatBugs,
        caption: l.dashboardStatUrgent(urgentBugs),
        onTap: () => open(DashboardItemKind.bug),
      ),
      _Tile(
        icon: LucideIcons.clipboardList500,
        color: c.accent,
        value: queue.openTasks,
        label: l.dashboardStatTasks,
        caption: l.dashboardStatInProgress(doingTasks),
        onTap: () => open(DashboardItemKind.task),
      ),
      _Tile(
        icon: LucideIcons.bookOpenText500,
        color: c.info,
        value: d?.storyTotal,
        label: l.dashboardStatStories,
        caption: l.dashboardStatAssigned,
      ),
      _Tile(
        icon: LucideIcons.kanban500,
        color: c.caution,
        value: d?.executionTotal,
        label: l.dashboardStatSprints,
        caption: l.dashboardStatRunning(running),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across on a wide window, two by two on a narrow one.
        final perRow = constraints.maxWidth < s.xl6 * 18 ? 2 : 4;
        final width = (constraints.maxWidth - s.xl * (perRow - 1)) / perRow;
        return Wrap(
          spacing: s.xl,
          runSpacing: s.xl,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.caption,
    this.onTap,
  });

  final IconData icon;
  final Color color;

  /// Null until the dashboard has loaded.
  final int? value;
  final String label;
  final String caption;
  final VoidCallback? onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final tappable = widget.onTap != null;
    final active = tappable && _hover;
    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.all(s.xl3),
          decoration: BoxDecoration(
            color: active ? c.mix(c.surface, widget.color, 0.05) : c.surface,
            borderRadius: BorderRadius.circular(context.radii.lg),
            border: Border.fromBorderSide(
              active
                  ? BorderSide(color: c.mixT(widget.color, 0.5))
                  : context.hairlineSide,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: s.xl6 * 0.8,
                    height: s.xl6 * 0.8,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.mixT(widget.color, 0.14),
                      borderRadius: BorderRadius.circular(context.radii.md),
                    ),
                    child: Icon(widget.icon, size: s.xl3, color: widget.color),
                  ),
                  const Spacer(),
                  if (tappable)
                    Icon(
                      LucideIcons.arrowUpRight300,
                      size: s.xl3,
                      color: active ? widget.color : c.textTertiary,
                    ),
                ],
              ),
              SizedBox(height: s.xl),
              Text(
                widget.value?.toString() ?? '–',
                style: t.displayLg.copyWith(
                  color: c.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmStrong.copyWith(color: c.textSecondary),
              ),
              SizedBox(height: s.xxs),
              Text(
                widget.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(color: c.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

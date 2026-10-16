import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shell_pane/sidebar_primitives.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../providers/zentao_board_providers.dart';
import '../widgets/zentao_execution_row.dart';

/// Level 2 node in the ZenTao Tasks navigation tree: represents a single Project.
/// Can be expanded to show child Executions (sprints), and tapped to filter tasks by project.
class ZentaoProjectTreeNode extends ConsumerStatefulWidget {
  const ZentaoProjectTreeNode({
    super.key,
    required this.account,
    required this.project,
    required this.tickets,
    required this.location,
    required this.openCount,
    required this.isPinned,
    required this.onPinToggle,
    this.isInPinned = false,
    this.onlyPinnedExecutions = false,
  });

  final Account account;
  final ProviderProject project;
  final List<Ticket> tickets;
  final ToolLocation location;
  final int openCount;
  final bool isPinned;
  final VoidCallback onPinToggle;
  final bool isInPinned;
  final bool onlyPinnedExecutions;

  @override
  ConsumerState<ZentaoProjectTreeNode> createState() =>
      _ZentaoProjectTreeNodeState();
}

class _ZentaoProjectTreeNodeState extends ConsumerState<ZentaoProjectTreeNode> {
  bool _hovered = false;
  bool? _pinnedExpanded;

  void _onToggleExpand(String key, bool currentExpanded) {
    if (widget.isInPinned) {
      setState(() => _pinnedExpanded = !currentExpanded);
    } else {
      ref.read(zentaoExecutionProjectsExpandedProvider.notifier).toggle(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final key = '${widget.account.id}:${widget.project.id}';

    final expanded = widget.isInPinned
        ? (_pinnedExpanded ?? true)
        : ref.watch(
            zentaoExecutionProjectsExpandedProvider.select(
              (set) => set.contains(key),
            ),
          );

    final selected =
        widget.location.scopeId == widget.project.id &&
        ref.watch(selectedZenTaoExecutionProvider) == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () {
              ref.read(appNavProvider.notifier).selectScope(widget.project.id);
              ref.read(selectedZenTaoExecutionProvider.notifier).clear();
            },
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: Container(
              height: context.sizes.controlSm,
              padding: EdgeInsets.symmetric(horizontal: s.xs),
              decoration: BoxDecoration(
                color: selected ? c.selectionFill : Colors.transparent,
                borderRadius: BorderRadius.circular(context.radii.sm),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _onToggleExpand(key, expanded),
                    borderRadius: BorderRadius.circular(context.radii.xs),
                    child: Padding(
                      padding: EdgeInsets.all(s.xxs),
                      child: Icon(
                        expanded
                            ? LucideIcons.chevronDown300
                            : LucideIcons.chevronRight300,
                        size: context.sizes.iconXs,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                  SizedBox(width: s.xxs),
                  Icon(
                    LucideIcons.folder300,
                    size: context.sizes.iconSm,
                    color: selected ? c.accent : c.textSecondary,
                  ),
                  SizedBox(width: s.xs),
                  Expanded(
                    child: Text(
                      widget.project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodySm.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected ? c.textPrimary : c.textSecondary,
                      ),
                    ),
                  ),
                  if (widget.openCount > 0) ...[
                    SidebarCountBadge(widget.openCount),
                    SizedBox(width: s.xs),
                  ],
                  if (widget.isPinned || _hovered)
                    SidebarPinButton(
                      pinned: widget.isPinned,
                      onTap: widget.onPinToggle,
                      tooltip: widget.isPinned ? l.unpinProject : l.pinProject,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          SidebarTreeBranch(
            child: _ProjectExecutions(
              account: widget.account,
              projectId: widget.project.id,
              tickets: widget.tickets,
              onlyPinned: widget.onlyPinnedExecutions,
            ),
          ),
      ],
    );
  }
}

class _ProjectExecutions extends ConsumerWidget {
  const _ProjectExecutions({
    required this.account,
    required this.projectId,
    required this.tickets,
    this.onlyPinned = false,
  });

  final Account account;
  final String projectId;
  final List<Ticket> tickets;
  final bool onlyPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final executionsAsync = ref.watch(
      zentaoExecutionsProvider((accountId: account.id, projectId: projectId)),
    );
    final pinnedKeys = {
      for (final e in ref.watch(
        appSettingsProvider.select((s) => s.pinnedExecutions),
      ))
        e.key,
    };

    return executionsAsync.when(
      data: (executions) {
        final displayed = onlyPinned
            ? executions
                .where((e) => pinnedKeys.contains('${account.id}:${e.id}'))
                .toList()
            : executions;
        if (displayed.isEmpty) {
          return onlyPinned
              ? const SizedBox.shrink()
              : SidebarStatusRow(label: l.noExecutions);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final execution in displayed)
              ZenTaoExecutionRow(
                key: ValueKey('exec_${execution.id}'),
                execution: execution,
                pinned: pinnedKeys.contains('${account.id}:${execution.id}'),
              ),
          ],
        );
      },
      loading: () =>
          SidebarStatusRow(label: l.loadingExecutions, loading: true),
      error: (_, _) => SidebarStatusRow(
        label: l.executionsUnavailable,
        isError: true,
        onRetry: () => ref.invalidate(
          zentaoExecutionsProvider((
            accountId: account.id,
            projectId: projectId,
          )),
        ),
      ),
    );
  }
}

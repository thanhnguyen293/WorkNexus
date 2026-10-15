import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/zentao_board_providers.dart';

/// Interactive tree node for a ZenTao Project in the header switcher popover.
///
/// Clicking the folder selects the project (filtering by its child group).
/// Expanding the chevron reveals child executions with bullet icons;
/// clicking a child execution selects and filters exclusively for that execution.
class ZenTaoPopoverProjectNode extends ConsumerStatefulWidget {
  const ZenTaoPopoverProjectNode({
    super.key,
    required this.targetAccountId,
    required this.project,
    required this.isFolderSelected,
    required this.currentExec,
    required this.openCount,
    required this.onSelectProject,
    required this.onSelectExecution,
    this.initiallyExpanded = false,
  });

  final String targetAccountId;
  final ProviderProject project;
  final bool isFolderSelected;
  final ZenTaoExecutionSelection? currentExec;
  final int openCount;
  final ValueChanged<ProviderProject> onSelectProject;
  final ValueChanged<ProviderExecution> onSelectExecution;
  final bool initiallyExpanded;

  @override
  ConsumerState<ZenTaoPopoverProjectNode> createState() =>
      _ZenTaoPopoverProjectNodeState();
}

class _ZenTaoPopoverProjectNodeState
    extends ConsumerState<ZenTaoPopoverProjectNode> {
  late bool _expanded =
      widget.initiallyExpanded ||
      widget.currentExec?.projectId == widget.project.id;

  @override
  void didUpdateWidget(covariant ZenTaoPopoverProjectNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentExec?.projectId == widget.project.id &&
        oldWidget.currentExec?.projectId != widget.project.id) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCurrentFolder = widget.isFolderSelected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Project folder row
        InkWell(
          onTap: () => widget.onSelectProject(widget.project),
          borderRadius: BorderRadius.circular(context.radii.xs),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: isCurrentFolder ? c.selectionFill : Colors.transparent,
              borderRadius: BorderRadius.circular(context.radii.xs),
            ),
            child: Row(
              children: [
                // Expand / Collapse Chevron
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(context.radii.xs),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Icon(
                      _expanded
                          ? LucideIcons.chevronDown300
                          : LucideIcons.chevronRight300,
                      size: 13,
                      color: c.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  LucideIcons.folder300,
                  size: 14,
                  color: isCurrentFolder ? c.accent : c.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySm.copyWith(
                      color: isCurrentFolder ? c.accent : c.textPrimary,
                      fontWeight: isCurrentFolder
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (widget.openCount > 0) ...[
                  Text(
                    '${widget.openCount}',
                    style: context.typography.monoXs.copyWith(
                      color: isCurrentFolder ? c.accent : c.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentFolder
                        ? c.accent.withValues(alpha: 0.15)
                        : c.surfaceSubtle,
                    borderRadius: BorderRadius.circular(context.radii.xs),
                  ),
                  child: Text(
                    'Project',
                    style: context.typography.monoXs.copyWith(
                      color: isCurrentFolder ? c.accent : c.textTertiary,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Child executions when expanded
        if (_expanded)
          _PopoverProjectExecutions(
            accountId: widget.targetAccountId,
            projectId: widget.project.id,
            currentExec: widget.currentExec,
            onSelectExecution: widget.onSelectExecution,
          ),
      ],
    );
  }
}

class _PopoverProjectExecutions extends ConsumerWidget {
  const _PopoverProjectExecutions({
    required this.accountId,
    required this.projectId,
    required this.currentExec,
    required this.onSelectExecution,
  });

  final String accountId;
  final String projectId;
  final ZenTaoExecutionSelection? currentExec;
  final ValueChanged<ProviderExecution> onSelectExecution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final executionsAsync = ref.watch(
      zentaoExecutionsProvider((accountId: accountId, projectId: projectId)),
    );

    return executionsAsync.when(
      data: (executions) {
        if (executions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(left: 32, top: 2, bottom: 4),
            child: Text(
              'No executions',
              style: context.typography.caption.copyWith(
                color: c.textTertiary,
                fontSize: 11,
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final exec in executions)
              _PopoverExecutionItem(
                execution: exec,
                isSelected: currentExec?.executionId == exec.id,
                onTap: () => onSelectExecution(exec),
              ),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: c.accent),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(left: 32, top: 2, bottom: 4),
        child: Text(
          'Executions unavailable',
          style: context.typography.caption.copyWith(
            color: c.textTertiary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _PopoverExecutionItem extends StatelessWidget {
  const _PopoverExecutionItem({
    required this.execution,
    required this.isSelected,
    required this.onTap,
  });

  final ProviderExecution execution;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.xs),
      child: Container(
        padding: const EdgeInsets.only(left: 28, right: 8, top: 4, bottom: 4),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.xs),
        ),
        child: Row(
          children: [
            // Execution bullet dot (purple/accent circle)
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isSelected ? c.accent : c.accent.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                execution.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.monoXs.copyWith(
                  color: isSelected ? c.accent : c.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

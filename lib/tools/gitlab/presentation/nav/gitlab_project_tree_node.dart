import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/shell_pane/sidebar_primitives.dart';
import '../../domain/entities/gitlab_project_tree.dart';
import '../../domain/value_objects/gitlab_item_kind.dart';
import '../providers/gitlab_board_providers.dart';

/// A project leaf row in the hierarchical GitLab project tree.
class GitLabProjectTreeNode extends ConsumerStatefulWidget {
  const GitLabProjectTreeNode({
    super.key,
    required this.project,
    required this.openCount,
    required this.selected,
    required this.isPinned,
    required this.onPinToggle,
  });

  final ProviderProject project;
  final int openCount;
  final bool selected;
  final bool isPinned;
  final VoidCallback onPinToggle;

  @override
  ConsumerState<GitLabProjectTreeNode> createState() =>
      _GitLabProjectTreeNodeState();
}

class _GitLabProjectTreeNodeState extends ConsumerState<GitLabProjectTreeNode> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final shortName = gitlabShortProjectName(widget.project);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          ref.read(appNavProvider.notifier).selectScope(widget.project.id);
          ref
              .read(selectedGitLabProjectProvider.notifier)
              .select(widget.project);
          ref
              .read(gitlabKindProvider.notifier)
              .set(GitLabItemKind.mergeRequest);
          ref
              .read(filterStateProvider.notifier)
              .openBoard(ref.read(boardKeyProvider));
        },
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Container(
          height: context.sizes.controlSm,
          padding: EdgeInsets.symmetric(horizontal: s.xs),
          decoration: BoxDecoration(
            color: widget.selected ? c.selectionFill : Colors.transparent,
            borderRadius: BorderRadius.circular(context.radii.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.selected ? c.accent : c.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: s.sm),
              Expanded(
                child: Text(
                  shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.mono.copyWith(
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: widget.selected ? c.textPrimary : c.textSecondary,
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
                  tooltip: widget.isPinned ? l.unpinProject : l.pinProject,
                  onTap: widget.onPinToggle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/provider_detail_sections.dart';
import '../util/gitlab_mr_phase.dart';
import 'gitlab_mr_commands.dart';
import 'mr_async_button.dart';
import 'mr_widget_card.dart';

/// The merge widget of an open MR, in GitLab's three states: blocked as a draft
/// (→ Mark as ready), blocked behind its target (→ Rebase), or mergeable
/// (→ Merge, with the delete-source-branch / squash options). Hidden once the
/// MR is merged or closed — `GitLabMrOutcomePanel` takes over.
class GitLabMrMergePanel extends StatefulWidget {
  const GitLabMrMergePanel({
    super.key,
    required this.ticket,
    required this.entity,
    required this.commands,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final GitLabMrCommands commands;

  @override
  State<GitLabMrMergePanel> createState() => _GitLabMrMergePanelState();
}

class _GitLabMrMergePanelState extends State<GitLabMrMergePanel> {
  late bool _removeSourceBranch;
  late bool _squash;

  @override
  void initState() {
    super.initState();
    _resetOptions();
  }

  @override
  void didUpdateWidget(covariant GitLabMrMergePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refresh that changed the MR's own settings (e.g. edited on the web)
    // wins over the local toggles.
    if (oldWidget.entity.squash != widget.entity.squash ||
        oldWidget.entity.removeSourceBranch !=
            widget.entity.removeSourceBranch) {
      _resetOptions();
    }
  }

  void _resetOptions() {
    _removeSourceBranch = widget.entity.removeSourceBranch ?? false;
    _squash = widget.entity.squash ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final entity = widget.entity;
    final commands = widget.commands;
    final phase = gitLabMrPhase(widget.ticket, entity);
    if (!phase.isActive) return const SizedBox.shrink();

    final isDraft = phase == GitLabMrPhase.draft;
    final mergeStatus = humanizeMergeState(entity.mergeStatus);
    final commitsBehind = entity.commitsBehind ?? 0;
    final needsRebase = gitLabMrNeedsRebase(entity);
    final mergeable = !isDraft && !needsRebase;
    return MrWidgetCard(
      icon: mergeable ? LucideIcons.checkCircle300 : LucideIcons.minusCircle300,
      iconColor: mergeable ? c.success : (isDraft ? c.textSecondary : c.error),
      title: Text(
        isDraft
            ? l.mergeBlockedDraft
            : needsRebase
            ? l.mergeBlockedNeedRebase
            : (mergeStatus.isEmpty
                  ? l.mergeReady
                  : l.mergeStatusValue(mergeStatus)),
      ),
      actions: [
        if (isDraft)
          MrAsyncButton(
            label: l.markAsReady,
            onPressed: () => commands.setDraft(false),
          )
        else if (needsRebase)
          MrAsyncButton(label: l.rebase, onPressed: commands.rebase)
        else
          MrAsyncButton(
            label: l.gitlabMerge,
            onPressed: () => commands.merge(
              squash: _squash,
              removeSourceBranch: _removeSourceBranch,
            ),
          ),
      ],
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mergeable) ...[
            Wrap(
              spacing: context.spacing.lg,
              runSpacing: context.spacing.xs,
              children: [
                _MergeOption(
                  label: l.deleteSourceBranch,
                  value: _removeSourceBranch,
                  onChanged: (v) => setState(() => _removeSourceBranch = v),
                ),
                _MergeOption(
                  label: l.squashCommits,
                  value: _squash,
                  onChanged: (v) => setState(() => _squash = v),
                ),
              ],
            ),
            SizedBox(height: context.spacing.md),
          ],
          Text(
            l.mergeDetails,
            style: context.typography.secondaryStrong.copyWith(
              color: c.textPrimary,
            ),
          ),
          if (commitsBehind > 0)
            MrDetailBullet(child: Text(l.commitsBehindTarget(commitsBehind))),
          if ((entity.sourceBranch ?? '').isNotEmpty &&
              (entity.targetBranch ?? '').isNotEmpty)
            MrDetailBullet(
              child: Text('${entity.sourceBranch} → ${entity.targetBranch}'),
            ),
          if (mergeStatus.isNotEmpty)
            MrDetailBullet(child: Text(l.mergeStatusValue(mergeStatus))),
        ],
      ),
    );
  }
}

/// A labelled checkbox; the label toggles it too.
class _MergeOption extends StatelessWidget {
  const _MergeOption({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      borderRadius: BorderRadius.circular(context.radii.sm),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.only(right: context.spacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              mouseCursor: WidgetStateMouseCursor.clickable,
              visualDensity: VisualDensity.compact,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

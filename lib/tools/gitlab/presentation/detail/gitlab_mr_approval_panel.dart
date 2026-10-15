import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/provider_user_avatar.dart';
import '../util/gitlab_mr_phase.dart';
import 'gitlab_mr_commands.dart';
import 'mr_async_button.dart';
import 'mr_widget_card.dart';

/// GitLab's approval widget: who approved (or how many approvals are still
/// needed) and, while the MR is open, Approve / Revoke approval. A merged MR
/// keeps the record of who approved; a closed one shows nothing.
class GitLabMrApprovalPanel extends StatelessWidget {
  const GitLabMrApprovalPanel({
    super.key,
    required this.ticket,
    required this.entity,
    required this.commands,
    required this.avatarLoader,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final GitLabMrCommands commands;
  final AvatarLoader avatarLoader;

  /// Whether the widget has anything to show for this MR.
  static bool shows(Ticket ticket, GitLabItemEntity entity) =>
      switch (gitLabMrPhase(ticket, entity)) {
        GitLabMrPhase.closed => false,
        GitLabMrPhase.merged => entity.approvedBy.isNotEmpty,
        GitLabMrPhase.draft || GitLabMrPhase.open => true,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    if (!shows(ticket, entity)) return const SizedBox.shrink();
    final open = gitLabMrPhase(ticket, entity).isActive;
    final approvers = entity.approvedBy;
    final youApproved = entity.userHasApproved ?? false;
    final left = entity.approvalsLeft ?? 0;
    final Widget title;
    if (approvers.isEmpty) {
      title = Text(left > 0 ? l.approvalsLeft(left) : l.approvalOptional);
    } else if (youApproved && approvers.length == 1) {
      title = Text(l.approvedByYou);
    } else {
      title = Wrap(
        spacing: context.spacing.sm,
        runSpacing: context.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l.approvedByLabel),
          for (final name in approvers)
            Tooltip(
              message: name,
              child: ProviderAvatarImage(
                name: name,
                avatarUrl: entity.userAvatarUrls[name],
                imageLoader: avatarLoader,
              ),
            ),
        ],
      );
    }
    return MrWidgetCard(
      icon: approvers.isEmpty
          ? LucideIcons.userCheck300
          : LucideIcons.checkCircle300,
      iconColor: approvers.isEmpty ? c.textSecondary : c.success,
      title: title,
      actions: [
        if (open && youApproved)
          MrAsyncButton(
            kind: MrButtonKind.secondary,
            label: l.revokeApproval,
            onPressed: commands.unapprove,
          )
        else if (open && (entity.userCanApprove ?? true))
          MrAsyncButton(label: l.approve, onPressed: commands.approve),
      ],
    );
  }
}

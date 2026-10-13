import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/gitlab_mr_phase.dart';
import 'gitlab_mr_commands.dart';

/// The MR header's "⋮" menu, as on GitLab: Mark as ready / draft and Close
/// while open, Reopen once closed, and Copy reference (`group/project!42`).
class GitLabMrMoreButton extends StatelessWidget {
  const GitLabMrMoreButton({
    super.key,
    required this.ticket,
    required this.entity,
    required this.commands,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final GitLabMrCommands commands;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      outlined: true,
      icon: LucideIcons.ellipsisVertical300,
      tooltip: AppL10n.of(context).more,
      onPressed: () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) async {
    final l = AppL10n.of(context);
    final phase = gitLabMrPhase(ticket, entity);
    final open = phase.isActive;
    final isDraft = phase == GitLabMrPhase.draft;
    final path = entity.projectPath ?? '';
    final reference = '$path!${ticket.externalKey}';
    final items = <(AppMenuEntry, Future<void> Function())>[
      if (open && isDraft)
        (
          AppMenuEntry(icon: LucideIcons.circleCheck300, label: l.markAsReady),
          () => commands.setDraft(false),
        ),
      if (open && !isDraft)
        (
          AppMenuEntry(
            icon: LucideIcons.gitPullRequestDraft300,
            label: l.markAsDraft,
          ),
          () => commands.setDraft(true),
        ),
      if (path.isNotEmpty)
        (
          AppMenuEntry(icon: LucideIcons.copy300, label: l.copyReference),
          () => _copy(context, reference, l.referenceCopied),
        ),
      if (open)
        (
          AppMenuEntry(
            icon: LucideIcons.gitPullRequestClosed300,
            label: l.closeMergeRequest,
            destructive: true,
            dividerBefore: true,
          ),
          commands.close,
        ),
      if (phase == GitLabMrPhase.closed)
        (
          AppMenuEntry(
            icon: LucideIcons.rotateCw300,
            label: l.reopenMergeRequest,
            dividerBefore: true,
          ),
          commands.reopen,
        ),
    ];
    final box = context.findRenderObject() as RenderBox?;
    final at =
        box?.localToGlobal(Offset(0, box.size.height + context.spacing.xs)) ??
        Offset.zero;
    final picked = await showAppContextMenu(
      context,
      at: at,
      entries: [for (final (entry, _) in items) entry],
    );
    // The snackbar reports the outcome; nothing here waits on it.
    if (picked != null && picked < items.length) unawaited(items[picked].$2());
  }

  Future<void> _copy(BuildContext context, String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showAppSnack(context, done);
  }
}

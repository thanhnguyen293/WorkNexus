import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/merge_request_state_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/detail_back_button.dart';
import '../../../../shared/detail/presentation/widgets/detail_panel_header_actions.dart';
import '../util/template_runs.dart';
import 'gitlab_mr_breadcrumb.dart';
import 'gitlab_mr_commands.dart';
import 'gitlab_mr_more_button.dart';

/// The two-pane MR header, laid out like GitLab's: title and panel-level
/// actions (refresh / link / edit / close-panel), then the metadata line —
/// status pill, "**author** requested to merge `source` into `target`" with a
/// copy button per branch, and the opened-at time. No rule underneath: the tab
/// strip's hairline closes the header, as on GitLab.
class GitLabMrHeader extends StatelessWidget {
  const GitLabMrHeader({
    super.key,
    required this.ticket,
    required this.entity,
    required this.onClose,
    required this.onSync,
    required this.commands,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final VoidCallback onClose;
  final VoidCallback onSync;
  final GitLabMrCommands commands;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl3,
        context.spacing.xl2,
        context.spacing.lg,
        context.spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entity.projectPath case final path? when path.isNotEmpty) ...[
            GitLabMrBreadcrumb(
              projectPath: path,
              reference: ticket.externalKey,
              mrUrl: ticket.url,
            ),
            SizedBox(height: context.spacing.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DetailBackButton(),
              Expanded(
                child: Text(
                  ticket.title,
                  style: context.typography.display.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              DetailPanelHeaderActions(
                ticket: ticket,
                onSync: onSync,
                onClosePanel: onClose,
                menu: GitLabMrMoreButton(
                  ticket: ticket,
                  entity: entity,
                  commands: commands,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          Wrap(
            spacing: context.spacing.sm,
            runSpacing: context.spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MergeRequestStatePill(
                status: ticket.providerStatus,
                provider: ProviderType.gitlab,
              ),
              for (final (slot, text) in _mergeSentence(
                l,
                author: entity.author ?? '',
                source: entity.sourceBranch ?? '',
                target: entity.targetBranch ?? '',
              ))
                switch (slot) {
                  _Slot.author => Text(
                    text,
                    style: context.typography.secondaryStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  _Slot.branch => _BranchRef(text),
                  _Slot.text => Text(
                    text,
                    style: context.typography.secondary.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                },
              if (ticket.createdAt != null)
                Text(
                  formatWhen(context, ticket.createdAt),
                  style: context.typography.secondary.copyWith(
                    color: c.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Slot { author, branch, text }

/// "{author} requested to merge {source} into {target}" cut into runs, so the
/// author can be set in bold and each branch as a ref while translators keep
/// control of the word order. Without both branches it falls back to just
/// "{author} requested to merge".
List<(_Slot, String)> _mergeSentence(
  AppL10n l, {
  required String author,
  required String source,
  required String target,
}) {
  if (source.isEmpty || target.isEmpty) {
    return [if (author.isNotEmpty) (_Slot.text, l.mrRequestedToMerge(author))];
  }
  return [
    for (final run in templateRuns(
      (m) => l.mrRequestedToMergeInto(m[0], m[1], m[2]),
      3,
    ))
      ?switch (run.slot) {
        0 => author.isEmpty ? null : (_Slot.author, author),
        1 => (_Slot.branch, source),
        2 => (_Slot.branch, target),
        _ => run.text.trim().isEmpty ? null : (_Slot.text, run.text.trim()),
      },
  ];
}

/// A branch name in GitLab's ref style — monospace on an accent tint — with a
/// copy button beside it.
class _BranchRef extends StatelessWidget {
  const _BranchRef(this.branch);

  final String branch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.xs,
            vertical: context.spacing.xxs,
          ),
          decoration: BoxDecoration(
            color: c.mixT(c.accent, 0.1),
            borderRadius: BorderRadius.circular(context.radii.xs),
          ),
          child: SelectableText(
            branch,
            style: context.typography.mono.copyWith(
              fontSize: context.typography.bodySm.fontSize,
              color: c.accent,
            ),
          ),
        ),
        _CopyBranchButton(branch),
      ],
    );
  }
}

/// Copies a branch name, flashing a check mark as confirmation.
class _CopyBranchButton extends StatefulWidget {
  const _CopyBranchButton(this.branch);

  final String branch;

  @override
  State<_CopyBranchButton> createState() => _CopyBranchButtonState();
}

class _CopyBranchButtonState extends State<_CopyBranchButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.branch));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AppIconButton(
      icon: _copied ? LucideIcons.check300 : LucideIcons.copy300,
      size: AppIconButtonSize.small,
      tooltip: _copied ? l.linkCopied : l.copyBranchName,
      onPressed: _copy,
    );
  }
}

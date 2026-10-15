import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';

/// One row in the GitHub Pull Requests list view (specs S5.5).
/// Displays PR icon, title, subtitle (`#{n} · {repo} · {source} → {target}`),
/// and a state pill (Draft / Review / Merged / Closed).
class GitHubPrRow extends ConsumerWidget {
  const GitHubPrRow({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final openId = ref.watch(openTicketIdProvider);
    final isSelected = openId == ticket.id;

    final entity = ticket.providerEntity is GitHubItemEntity
        ? ticket.providerEntity as GitHubItemEntity
        : null;

    final (stateLabel, stateColor) = () {
      if (entity?.draft == true) {
        return (l.githubColDraft, c.textTertiary);
      }
      if (entity?.merged == true) {
        return (l.githubColMerged, c.accent);
      }
      if (ticket.status == UnifiedStatus.done) {
        return (l.githubColClosed, c.error);
      }
      return (l.githubColOpen, c.success);
    }();

    final repo = entity?.repo ?? ticket.projectId;
    final branchPart =
        (entity?.headBranch != null && entity?.baseBranch != null)
        ? ' · ${entity!.headBranch} → ${entity.baseBranch}'
        : '';
    final subtitle = '#${ticket.externalKey} · $repo$branchPart';

    return HoverSurface(
      onTap: () => ref.read(appNavProvider.notifier).openTicket(ticket.id),
      selected: isSelected,
      borderRadius: BorderRadius.circular(context.radii.sm),
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
      child: Row(
        children: [
          Icon(LucideIcons.gitPullRequest300, size: 18, color: stateColor),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ticket.title,
                  style: context.typography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isSelected ? c.accent : c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: s.xxs),
                Text(
                  subtitle,
                  style: context.typography.caption.copyWith(
                    color: c.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: s.md),
          TintedPill(color: stateColor, label: stateLabel, pill: true),
        ],
      ),
    );
  }
}

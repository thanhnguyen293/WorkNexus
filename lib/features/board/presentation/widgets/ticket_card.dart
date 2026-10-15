import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/label_chips.dart';
import '../../../translation/presentation/translation_providers.dart';
import '../board_providers.dart';
import 'ticket_card_meta.dart';

/// A board card rendering one ticket, matching the editorial design.
class TicketCard extends ConsumerWidget {
  const TicketCard(this.ticket, {super.key});
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // Each watch narrows to the one value the card draws, so a card rebuilds
    // for its own ticket, not for every change to the lookups, the settings
    // or the open ticket.
    final wsColorValue = ref.watch(
      lookupsProvider.select((l) {
        final account = l.accounts[ticket.accountId];
        return account == null
            ? null
            : l.workspaces[account.workspaceId]?.colorValue;
      }),
    );
    final wsColor = wsColorValue == null
        ? c.workspaceFallback
        : Color(wsColorValue);
    final tint = ref.watch(appSettingsProvider.select((s) => s.companyTint));
    final selected = ref.watch(
      openTicketIdProvider.select((id) => id == ticket.id),
    );
    final pending = ref.watch(
      ticketActionPendingProvider.select((ids) => ids.contains(ticket.id)),
    );

    final trStatus = ref.watch(
      translationStatusProvider(ticket.id).select((t) => t.state),
    );
    final cardLabels = visibleUserLabels(ticket.labels);
    final labelColors = labelColorsOf(ticket);

    final stripeWidth = selected ? 5.0 : 4.0;
    final bg = selected
        ? c.mix(c.card, wsColor, 0.16)
        : c.tintedCard(wsColor, enabled: tint);
    // Uniform rounded border (drawn by the decoration) so the line follows the
    // corners; a non-uniform border can't take a borderRadius, and clipping a
    // straight-sided border to a rounded rect drops the line at the corners. The
    // left edge is covered by the workspace stripe, so a full border is fine.
    final border = context.borders.showOutline
        ? Border.all(color: c.border)
        : null;

    return Opacity(
      opacity: pending ? 0.48 : 1,
      child: HoverSurface(
        onTap: pending
            ? null
            : () => ref.read(appNavProvider.notifier).openTicket(ticket.id),
        color: bg,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: border,
        // Outline surfaces also firm up the line on hover.
        hoverBorder: border == null ? null : Border.all(color: c.borderStrong),
        // The stripe is painted, not laid out: a clipped row with an
        // intrinsic-height pass cost every card an extra layout and a clip
        // layer on each scroll and resize.
        child: CustomPaint(
          painter: _WorkspaceStripe(
            color: wsColor,
            width: stripeWidth,
            radius: context.radii.card,
          ),
          child: Padding(
            padding: context.spacing.cardPadding.copyWith(
              left: context.spacing.cardPadding.left + stripeWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ticketRef(
                        ticket.providerType,
                        ticket.externalKey,
                        ticket.externalType,
                      ),
                      style: context.typography.mono.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                    SizedBox(width: context.spacing.sm),
                    Expanded(
                      child: switch (ticket.providerEntity) {
                        GitLabItemEntity(:final projectPath?)
                            when projectPath.isNotEmpty =>
                          _ProjectPath(projectPath),
                        _ => const SizedBox.shrink(),
                      },
                    ),

                    if (ticket.severity != null) SeverityTag(ticket.severity!),
                    if (hasExplicitPriority(ticket)) ...[
                      if (ticket.severity != null)
                        SizedBox(width: context.spacing.sm),
                      PriorityTag(ticket.providerType, ticket.priority),
                    ],
                  ],
                ),
                SizedBox(height: context.spacing.md),
                Text(
                  ticket.title,
                  style: context.typography.cardTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                if (cardLabels.isNotEmpty) ...[
                  SizedBox(height: context.spacing.md),
                  LabelChips(
                    labels: cardLabels,
                    colors: labelColors.background,
                    textColors: labelColors.text,
                  ),
                ],
                SizedBox(height: context.spacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AssigneeChip(
                        ticket.assignee,
                        wsColor,
                        // Chat photos exist for ZenTao people only.
                        accountId: ticket.providerType == ProviderType.zentao
                            ? ticket.accountId
                            : null,
                      ),
                    ),
                    SizedBox(width: context.spacing.sm),
                    TranslationDot(trStatus),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The workspace colour down the card's left edge, kept inside the card's
/// rounded corners.
class _WorkspaceStripe extends CustomPainter {
  const _WorkspaceStripe({
    required this.color,
    required this.width,
    required this.radius,
  });

  final Color color;
  final double width;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, size.height),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WorkspaceStripe old) =>
      old.color != color || old.width != width || old.radius != radius;
}

/// The GitLab repository an issue / MR belongs to, beside its reference, so
/// cards from several projects in one view can be told apart.
class _ProjectPath extends StatelessWidget {
  const _ProjectPath(this.path);

  final String path;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = path.split('/').map((s) => s.trim()).join('/');
    return Tooltip(
      message: label,
      child: Row(
        children: [
          Icon(
            LucideIcons.folderGit2300,
            size: context.spacing.xl,
            color: c.textTertiary,
          ),
          SizedBox(width: context.spacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

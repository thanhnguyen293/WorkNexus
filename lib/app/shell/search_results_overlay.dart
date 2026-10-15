import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/entities/ticket.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_popup_card.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/hover_surface.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/detail/presentation/widgets/ticket_status_pill.dart';

/// Floating results card for contextual search (design §7, specs S2.3).
/// Displays up to 8 ticket matches with key, title, and status pill.
class SearchResultsOverlay extends ConsumerWidget {
  const SearchResultsOverlay({
    super.key,
    required this.results,
    required this.highlightIndex,
    required this.onSelect,
    this.width = 460,
  });

  final List<Ticket> results;
  final int highlightIndex;
  final ValueChanged<Ticket> onSelect;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;

    if (results.isEmpty) {
      return AppPopupCard(
        child: SizedBox(
          width: width,
          child: Padding(
            padding: EdgeInsets.all(s.xl),
            child: Center(
              child: Text(
                AppL10n.of(context).searchNoResults,
                style: context.typography.bodySm.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AppPopupCard(
      child: SizedBox(
        width: width,
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.all(s.xs),
          itemCount: results.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
          itemBuilder: (context, i) {
            final ticket = results[i];
            final isHighlighted = i == highlightIndex;

            return _ResultRow(
              ticket: ticket,
              isHighlighted: isHighlighted,
              onTap: () => onSelect(ticket),
            );
          },
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.ticket,
    required this.isHighlighted,
    required this.onTap,
  });

  final Ticket ticket;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;

    return HoverSurface(
      onTap: onTap,
      selected: isHighlighted,
      borderRadius: BorderRadius.circular(r.sm),
      color: isHighlighted ? c.selectionFill : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
      child: Row(
        children: [
          ProviderBadge(ticket.providerType),
          SizedBox(width: s.sm),
          SizedBox(
            width: 80,
            child: Text(
              ticket.externalKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.monoSm.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              ticket.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodySm.copyWith(color: c.textPrimary),
            ),
          ),
          SizedBox(width: s.md),
          TicketStatusPill(ticket: ticket),
        ],
      ),
    );
  }
}

import '../../../core/database/database.dart';
import '../../../core/domain/entities/provider_entity.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/util/synthetic_labels.dart';

/// Merges a detail-fetch's [detailLabels] with the synthetic board-membership
/// labels ([kSyntheticLabelPrefixes]) carried on the already-stored
/// [existingLabels]. The detail endpoint omits those synthetic labels, so
/// without this a detail refresh would silently drop the ticket from its board.
List<String> mergeDetailLabels(
  List<String> detailLabels,
  List<String> existingLabels,
) {
  final preserved = existingLabels.where(
    (l) =>
        kSyntheticLabelPrefixes.any(l.startsWith) && !detailLabels.contains(l),
  );
  return [...detailLabels, ...preserved];
}

TicketProviderEntity? preserveLabelColors(
  TicketProviderEntity? fresh,
  TicketProviderEntity? existing,
) {
  if (fresh is GitLabItemEntity &&
      existing is GitLabItemEntity &&
      fresh.labelColors.isEmpty &&
      existing.labelColors.isNotEmpty) {
    return fresh.copyWith(
      labelColors: existing.labelColors,
      labelTextColors: existing.labelTextColors,
    );
  }
  return fresh;
}

/// Carries synthetic labels across refreshes so tickets don't lose board membership.
Future<List<Ticket>> carryMembershipLabels(
  AppDatabase db,
  List<Ticket> tickets,
) async {
  if (tickets.isEmpty) return tickets;
  final ids = [for (final t in tickets) t.id];
  final rows = await (db.select(
    db.tickets,
  )..where((r) => r.id.isIn(ids))).get();
  final priorLabels = {for (final r in rows) r.id: decodeLabels(r.labelsJson)};
  return [
    for (final t in tickets)
      if (priorLabels[t.id] case final prior?)
        t.copyWith(labels: mergeDetailLabels(t.labels, prior))
      else
        t,
  ];
}

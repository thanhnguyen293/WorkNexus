import '../../../core/domain/entities/provider_entity.dart';
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

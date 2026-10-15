import '../../../../core/domain/entities/ticket.dart';

/// Input parameters for [SearchLocalTickets].
class SearchLocalTicketsInput {
  const SearchLocalTicketsInput({
    required this.tickets,
    required this.query,
    this.accountId,
  });

  final List<Ticket> tickets;
  final String query;
  final String? accountId;
}

/// Pure use case: ranks and returns the top 8 matches across local tickets
/// for contextual search in the unified workspace shell (design §7, specs S2.3).
///
/// Ranking order:
/// 1. Exact key match (tier 0)
/// 2. Key prefix (tier 1)
/// 3. Title word-prefix (tier 2)
/// 4. Title contains (tier 3)
class SearchLocalTickets {
  const SearchLocalTickets();

  List<Ticket> call(SearchLocalTicketsInput input) {
    final q = input.query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final candidates = input.accountId == null
        ? input.tickets
        : input.tickets.where((t) => t.accountId == input.accountId).toList();

    final matches = <(int tier, Ticket ticket)>[];

    for (final ticket in candidates) {
      final key = ticket.externalKey.toLowerCase();
      final title = ticket.title.toLowerCase();

      if (key == q) {
        matches.add((0, ticket));
      } else if (key.startsWith(q)) {
        matches.add((1, ticket));
      } else {
        final words = title.split(RegExp(r'\s+'));
        if (words.any((w) => w.startsWith(q))) {
          matches.add((2, ticket));
        } else if (title.contains(q)) {
          matches.add((3, ticket));
        }
      }
    }

    // Sort by tier ascending (tier 0 is best match); stable for same tier
    matches.sort((a, b) => a.$1.compareTo(b.$1));

    return matches.map((m) => m.$2).take(8).toList();
  }
}

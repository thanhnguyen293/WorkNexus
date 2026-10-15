import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';

/// Scopes [tickets] to a single provider board — one account, one item type,
/// and (when given) a persisted membership label — reconciled against the
/// server [slice].
///
/// Offline-first: [slice] is the id set the last server sync returned for this
/// board, or `null` while that sync is still in flight or has failed (e.g.
/// offline). When it is null the persisted DB scope (account + type +
/// [membershipLabel]) alone decides membership, so cached tickets keep rendering
/// without a network round-trip; once the slice resolves it prunes anything the
/// server no longer lists. The membership label is what makes the offline scope
/// possible — it is stamped onto each ticket at sync time (e.g.
/// `gitlab-project:<id>`, `github-mine:<accountId>`).
class ScopeProviderTickets {
  const ScopeProviderTickets();

  List<Ticket> call({
    required List<Ticket> tickets,
    required String accountId,
    required ProviderType providerType,
    required String externalType,
    required Set<String>? slice,
    String? membershipLabel,
  }) {
    final type = externalType.toLowerCase();
    return [
      for (final t in tickets)
        if (t.accountId == accountId &&
            t.providerType == providerType &&
            (t.externalType ?? '').toLowerCase() == type &&
            (membershipLabel == null || t.labels.contains(membershipLabel)) &&
            (slice == null || slice.contains(t.id)))
          t,
    ];
  }
}

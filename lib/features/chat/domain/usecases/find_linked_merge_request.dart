import '../../../../core/domain/entities/ticket.dart';
import 'parse_merge_request_link.dart';

/// The stored GitLab MR / GitHub PR a chat link points to, matched by its
/// web address (host, project and number), or null.
class FindLinkedMergeRequest {
  const FindLinkedMergeRequest();

  Ticket? call(String url, List<Ticket> tickets) {
    const parse = ParseMergeRequestLink();
    final link = parse(url);
    if (link == null) return null;
    for (final t in tickets) {
      final other = t.url == null ? null : parse(t.url!);
      if (other != null && ParseMergeRequestLink.same(link, other)) return t;
    }
    return null;
  }
}

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';

/// The synced ZenTao ticket a chat link points to, if any. Understands the
/// PATH_INFO form (`…/bug-view-6466.html`) and the GET form
/// (`index.php?m=bug&f=view&bugID=6466`); the link's host must match the
/// ticket's server.
class FindLinkedTicket {
  const FindLinkedTicket();

  static final _pathInfo = RegExp(r'^(bug|task|story)-view-(\d+)\b');

  Ticket? call(String url, List<Ticket> tickets) {
    final ref = parse(url);
    if (ref == null) return null;
    for (final t in tickets) {
      if (t.providerType != ProviderType.zentao) continue;
      if (t.externalKey != ref.id) continue;
      if (t.externalType?.toLowerCase() != ref.type) continue;
      if (Uri.tryParse(t.url ?? '')?.host != ref.host) continue;
      return t;
    }
    return null;
  }

  /// The object type (bug/task/story), id and host a ZenTao link names.
  static ({String type, String id, String host})? parse(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (_pathInfo.firstMatch(last) case final m?) {
      return (type: m[1]!, id: m[2]!, host: uri.host);
    }
    final q = uri.queryParameters;
    final type = q['m'];
    if (q['f'] != 'view' || !const {'bug', 'task', 'story'}.contains(type)) {
      return null;
    }
    final id = q['${type}ID'] ?? q['id'];
    if (id == null || int.tryParse(id) == null) return null;
    return (type: type!, id: id, host: uri.host);
  }
}

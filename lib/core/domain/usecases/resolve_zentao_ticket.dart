import '../../error/failure.dart';
import '../../error/result.dart';
import '../adapters/zentao_ticket_service.dart';
import '../value_objects/zentao_ticket_id.dart';

/// Finds the WorkNexus ticket of ZenTao [type] (`bug`, `task`, `story`) [id]
/// so it can open in the detail panel: the synced one when the board has it,
/// otherwise fetched (and stored) from the ZenTao account on the given host.
class ResolveZenTaoTicket {
  const ResolveZenTaoTicket(this._service, {required this.isSynced});

  final ZenTaoTicketService _service;

  /// Whether the ticket with this WorkNexus id is already stored.
  final bool Function(String ticketId) isSynced;

  /// [accountId] is null when only the host is known (a link in chat); the
  /// synced lookup is skipped then and the ticket is always fetched.
  Future<Result<String>> call({
    String? accountId,
    required String host,
    required String type,
    required String id,
  }) async {
    if (accountId != null) {
      final local = zenTaoTicketId(accountId, type, id);
      if (isSynced(local)) return Ok(local);
    }
    if (host.isEmpty) {
      return const Err(NotFoundFailure('No ZenTao host for this ticket'));
    }
    return _service.fetchZenTaoTicket(host: host, type: type, id: id);
  }
}

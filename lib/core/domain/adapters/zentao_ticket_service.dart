import '../../error/result.dart';

/// Loads a single ZenTao ticket on demand — e.g. one linked in chat that
/// the board has not synced — so it can open in the detail panel.
abstract interface class ZenTaoTicketService {
  /// Fetches bug/task/story [id] of type [type] from the connected ZenTao
  /// account on [host], stores it and returns its WorkNexus ticket id.
  Future<Result<String>> fetchZenTaoTicket({
    required String host,
    required String type,
    required String id,
  });
}

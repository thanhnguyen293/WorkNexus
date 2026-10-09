import '../../error/result.dart';
import '../entities/ticket.dart';
import '../value_objects/unified_status.dart';

/// ZenTao's bug workflow actions. Each refreshes the ticket's cached detail.
/// Implemented in the data layer.
abstract interface class ZenTaoBugService {
  Future<Result<void>> resolveBug(
    Ticket ticket, {
    required String resolution,
    String? build,
    String? assignee,
    String? comment,
  });

  /// Reopens a resolved/closed bug; [optimisticStatus] shows until the sync.
  Future<Result<void>> activateBug(
    Ticket ticket, {
    String? build,
    String? assignee,
    String? comment,
    UnifiedStatus optimisticStatus = UnifiedStatus.todo,
  });

  Future<Result<void>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  });
}

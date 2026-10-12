import '../../../../core/error/result.dart';
import '../entities/saved_ticket_draft.dart';

/// The new bugs and tasks being written, kept on this device until they are
/// saved to ZenTao or discarded.
abstract interface class TicketDraftRepository {
  /// Every kept draft, the most recently changed first, live.
  Stream<List<SavedTicketDraft>> watchAll();

  /// Draft [id]; null when there is none (saved or discarded since).
  Future<Result<SavedTicketDraft?>> read(String id);

  /// Keeps [draft], replacing the one with its id.
  Future<Result<void>> save(SavedTicketDraft draft);

  Future<Result<void>> delete(String id);
}

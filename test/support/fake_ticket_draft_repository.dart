import 'dart:async';

import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/ticket_editor/domain/entities/saved_ticket_draft.dart';
import 'package:work_nexus/features/ticket_editor/domain/repositories/ticket_draft_repository.dart';

/// Kept drafts in memory, for widget tests that open the ticket editor or the
/// "+" menu.
class FakeTicketDraftRepository implements TicketDraftRepository {
  FakeTicketDraftRepository([Iterable<SavedTicketDraft> drafts = const []])
    : _drafts = {for (final d in drafts) d.id: d};

  final Map<String, SavedTicketDraft> _drafts;

  /// Makes reads / deletes fail, as a broken database would.
  bool failReads = false;
  bool failDeletes = false;

  static const _broken = StorageFailure('Could not keep the draft');
  final _changes = StreamController<void>.broadcast();

  List<SavedTicketDraft> get all =>
      _drafts.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Stream<List<SavedTicketDraft>> watchAll() async* {
    yield all;
    await for (final _ in _changes.stream) {
      yield all;
    }
  }

  @override
  Future<Result<SavedTicketDraft?>> read(String id) async =>
      failReads ? const Err(_broken) : Ok(_drafts[id]);

  @override
  Future<Result<void>> save(SavedTicketDraft draft) async {
    _drafts[draft.id] = draft;
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (failDeletes) return const Err(_broken);
    _drafts.remove(id);
    _changes.add(null);
    return const Ok(null);
  }
}

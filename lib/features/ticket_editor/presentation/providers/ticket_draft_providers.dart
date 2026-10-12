import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/saved_ticket_draft.dart';
import '../../domain/repositories/ticket_draft_repository.dart';

final ticketDraftRepositoryProvider = Provider<TicketDraftRepository>(
  (ref) => getIt<TicketDraftRepository>(),
);

/// Every kept bug / task draft, the most recently changed first.
final ticketDraftsProvider = StreamProvider.autoDispose<List<SavedTicketDraft>>(
  (ref) => ref.watch(ticketDraftRepositoryProvider).watchAll(),
);

/// Keeps a new ticket's draft while it is written: a change is kept once
/// typing pauses, and a change still waiting when the editor closes is kept
/// then ([flush]).
class DraftAutosave {
  DraftAutosave(this._repository, {this.delay = defaultDelay});

  static const defaultDelay = Duration(milliseconds: 800);

  final TicketDraftRepository _repository;
  final Duration delay;

  Timer? _timer;

  /// Builds what to keep, read when the draft is written so it holds the
  /// latest change; null when there is nothing worth keeping.
  SavedTicketDraft? Function()? _pending;
  void Function(Result<DateTime> kept)? _onKept;

  /// Keeps what [build] gives once [delay] passes without another change;
  /// [onKept] is told when it was kept, or why it could not be.
  void schedule(
    SavedTicketDraft? Function() build, {
    void Function(Result<DateTime> kept)? onKept,
  }) {
    _pending = build;
    _onKept = onKept;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  /// Keeps the waiting change now, if there is one.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final build = _pending;
    final onKept = _onKept;
    _pending = null;
    final draft = build?.call();
    if (draft == null) return;
    final res = await _repository.save(draft);
    onKept?.call(switch (res) {
      Ok() => Ok(draft.updatedAt),
      Err(:final failure) => Err<DateTime>(failure),
    });
  }

  /// Drops the waiting change (the ticket was saved or the draft discarded).
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  /// Cancels any waiting change and deletes draft [id].
  Future<Result<void>> discard(String id) {
    cancel();
    return _repository.delete(id);
  }

  /// Draft [id], telling a draft that is gone (null) from one that could not
  /// be read (thrown, so the editor shows its error and can retry).
  static Future<SavedTicketDraft?> read(
    TicketDraftRepository repository,
    String id,
  ) async => switch (await repository.read(id)) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}

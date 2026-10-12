import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../domain/entities/saved_ticket_draft.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import 'ticket_draft_providers.dart';
import 'ticket_editor_state.dart';

/// Loads, edits and saves the bug the editor is open on ([NewBugRoute] or
/// [EditBugRoute]). A new bug is kept as a draft while it is written, and
/// reopens from it ([NewBugRoute.draftId]).
class BugEditorController extends AsyncNotifier<BugEditorState> {
  BugEditorController(this.route);

  final TicketEditorRoute route;

  late DraftAutosave _autosave;

  @override
  Future<BugEditorState> build() async {
    final drafts = ref.read(ticketDraftRepositoryProvider);
    final autosave = _autosave = DraftAutosave(drafts);
    // Leaving the editor (Cancel, back, another view) keeps the last change.
    ref.onDispose(() => unawaited(autosave.flush()));
    if (route case NewBugRoute(:final draftId?)) {
      final kept = await DraftAutosave.read(drafts, draftId);
      if (kept is SavedBugDraft) return _restore(kept);
    }
    final editor = ref.read(zenTaoTicketEditorProvider);
    final res = switch (route) {
      NewBugRoute(
        :final productId,
        :final copyOf,
        :final executionId,
        :final taskId,
      ) =>
        await editor.newBugForm(
          route.accountId,
          productId,
          copyOf: copyOf,
          executionId: executionId,
          taskId: taskId,
        ),
      EditBugRoute(:final bugId) => await editor.editBugForm(
        route.accountId,
        bugId,
      ),
      _ => throw ArgumentError('Not a bug route: $route'),
    };
    return switch (res) {
      Ok(:final value) => _fresh(value),
      Err(:final failure) => throw failure,
    };
  }

  BugEditorState _fresh(BugForm form) {
    final uid = newFormUid();
    return BugEditorState(
      form: form,
      draft: form.draft,
      uid: uid,
      draftId: switch (route) {
        NewBugRoute(:final draftId) => draftId ?? uid,
        _ => null,
      },
    );
  }

  /// The form of [kept]'s product (with the choices of its project and
  /// execution), filled in as the draft was left.
  Future<BugEditorState> _restore(SavedBugDraft kept) async {
    final editor = ref.read(zenTaoTicketEditorProvider);
    final draft = kept.draft;
    final res = await editor.newBugForm(route.accountId, draft.product);
    final form = switch (res) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    final options = draft.project == '0' && draft.execution == '0'
        ? null
        : await _options(form.options, draft);
    return BugEditorState(
      form: options == null ? form : form.copyWith(options: options),
      draft: draft,
      uid: kept.uid,
      draftId: kept.id,
      draftSavedAt: kept.updatedAt,
    );
  }

  /// [draft]'s product / project / execution choices; null when ZenTao did
  /// not give them.
  Future<BugFormOptions?> _options(
    BugFormOptions current,
    BugDraft draft,
  ) async {
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .bugOptions(
          route.accountId,
          productId: draft.product,
          projectId: draft.project,
          executionId: draft.execution,
        );
    if (res is! Ok<BugFormOptions>) return null;
    return res.value.copyWith(
      // A product's choices hold the same lists of products and users.
      products: res.value.products.isEmpty
          ? current.products
          : res.value.products,
      users: res.value.users.isEmpty ? current.users : res.value.users,
    );
  }

  /// Keeps the draft once typing pauses — once something was written.
  void _keepDraft() {
    final now = _current;
    final id = now?.draftId;
    if (now == null || id == null) return;
    if (now.draftSavedAt == null && now.draft == now.form.draft) {
      return _autosave.cancel();
    }
    _autosave.schedule(
      SavedTicketDraft.bug(
        id: id,
        accountId: route.accountId,
        uid: now.uid,
        updatedAt: DateTime.now(),
        draft: now.draft.copyWith(newFiles: const []),
      ),
      onKept: (kept) {
        // Kept after the editor closed: there is no state to update.
        if (!ref.mounted) return;
        final now = _current;
        if (now == null) return;
        state = AsyncData(switch (kept) {
          Ok(:final value) => now.copyWith(draftSavedAt: value),
          Err(:final failure) => now.copyWith(failure: failure),
        });
      },
    );
  }

  /// Deletes the kept draft; later changes are not kept. False (with the
  /// state's `failure` set) when it could not be deleted, and the editor
  /// stays open.
  Future<bool> discardDraft() async {
    final current = _current;
    final id = current?.draftId;
    if (current == null || id == null) return true;
    final res = await _autosave.discard(id);
    final now = _current ?? current;
    switch (res) {
      case Ok():
        state = AsyncData(now.copyWith(draftId: null, draftSavedAt: null));
        return true;
      case Err(:final failure):
        if (ref.mounted) state = AsyncData(now.copyWith(failure: failure));
        return false;
    }
  }

  BugEditorState? get _current => state.asData?.value;

  void edit(BugDraft Function(BugDraft draft) change) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(draft: change(current.draft), missing: const {}),
    );
    _keepDraft();
  }

  /// Sets the product / project / execution, and reloads the choices that
  /// depend on them (modules, builds, stories…), dropping picks they no longer
  /// offer.
  Future<void> changeScope({
    String? product,
    String? project,
    String? execution,
  }) async {
    final current = _current;
    if (current == null) return;
    final draft = current.draft.copyWith(
      product: product ?? current.draft.product,
      project: project ?? current.draft.project,
      execution: execution ?? current.draft.execution,
      module: product == null ? current.draft.module : '0',
      story: '0',
      task: '0',
    );
    state = AsyncData(current.copyWith(draft: draft));
    _keepDraft();
    final options = await _options(current.form.options, draft);
    final now = _current;
    if (now == null || options == null) return;
    final builds = {for (final b in options.builds) b.value, 'trunk'};
    state = AsyncData(
      now.copyWith(
        form: now.form.copyWith(options: options),
        draft: now.draft.copyWith(
          openedBuilds: now.draft.openedBuilds.where(builds.contains).toList(),
        ),
      ),
    );
  }

  Future<String?> uploadImage(Uint8List bytes, String name) async {
    final current = _current;
    if (current == null) return null;
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .uploadImage(route.accountId, current.uid, bytes, name);
    return res is Ok<String> ? res.value : null;
  }

  /// Saves the bug; the saved bug's ticket id, or null when it was not saved
  /// (a field missing, or ZenTao refused it — see the state's `failure`).
  Future<String?> save() async {
    final current = _current;
    if (current == null || current.saving) return null;
    final missing = const ValidateBugDraft()(current.draft);
    if (missing.isNotEmpty) {
      state = AsyncData(current.copyWith(missing: missing));
      return null;
    }
    state = AsyncData(current.copyWith(saving: true, failure: null));
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .saveBug(
          route.accountId,
          current.form,
          current.draft,
          uid: current.uid,
        );
    final now = _current ?? current;
    switch (res) {
      case Ok(:final value):
        // In ZenTao now: nothing left to keep, and no later change kept again.
        state = AsyncData(now.copyWith(saving: false, draftId: null));
        if (now.draftId case final id?) await _autosave.discard(id);
        return value;
      case Err(:final failure):
        state = AsyncData(now.copyWith(saving: false, failure: failure));
        return null;
    }
  }
}

final bugEditorProvider = AsyncNotifierProvider.autoDispose
    .family<BugEditorController, BugEditorState, TicketEditorRoute>(
      BugEditorController.new,
    );

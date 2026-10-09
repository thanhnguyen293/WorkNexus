import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import 'ticket_editor_state.dart';

/// Loads, edits and saves the bug the editor is open on ([NewBugRoute] or
/// [EditBugRoute]).
class BugEditorController extends AsyncNotifier<BugEditorState> {
  BugEditorController(this.route);

  final TicketEditorRoute route;

  @override
  Future<BugEditorState> build() async {
    final editor = ref.read(zenTaoTicketEditorProvider);
    final res = switch (route) {
      NewBugRoute(:final productId) => await editor.newBugForm(
        route.accountId,
        productId,
      ),
      EditBugRoute(:final bugId) => await editor.editBugForm(
        route.accountId,
        bugId,
      ),
      _ => throw ArgumentError('Not a bug route: $route'),
    };
    return switch (res) {
      Ok(:final value) => BugEditorState(
        form: value,
        draft: value.draft,
        uid: newFormUid(),
      ),
      Err(:final failure) => throw failure,
    };
  }

  BugEditorState? get _current => state.asData?.value;

  void edit(BugDraft Function(BugDraft draft) change) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(draft: change(current.draft), missing: const {}),
    );
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
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .bugOptions(
          route.accountId,
          productId: draft.product,
          projectId: draft.project,
          executionId: draft.execution,
        );
    final now = _current;
    if (now == null || res is! Ok<BugFormOptions>) return;
    final options = res.value.copyWith(
      // A product's choices hold the same lists of products and users.
      products: res.value.products.isEmpty
          ? now.form.options.products
          : res.value.products,
      users: res.value.users.isEmpty ? now.form.options.users : res.value.users,
    );
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
        state = AsyncData(now.copyWith(saving: false));
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

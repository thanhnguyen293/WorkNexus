import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/domain/adapters/zentao_ticket_editor.dart';
import '../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../connections/data/zentao/zentao_ticket_forms.dart';
import 'sync_service.dart';

/// [ZenTaoTicketEditor] over each account's pooled ZenTao client; a saved bug
/// or task is fetched back and stored, so the board and detail show it.
class ZenTaoTicketEditorService implements ZenTaoTicketEditor {
  const ZenTaoTicketEditorService(this._sync);

  final SyncService _sync;

  Future<Result<T>> _run<T>(
    String accountId,
    Future<T> Function(ZenTaoTicketForms forms) run,
  ) async {
    final client = await _sync.zenTaoClientFor(accountId);
    if (client == null) {
      return const Err(AuthFailure('ZenTao account is not signed in'));
    }
    try {
      return Ok(await run(ZenTaoTicketForms(client)));
    } on Failure catch (failure) {
      return Err(failure);
    } on DioException catch (e) {
      return Err(
        NetworkFailure(e.message ?? 'ZenTao request failed', cause: e),
      );
    } on FormatException catch (e) {
      return Err(ParseFailure('ZenTao sent an unreadable form', cause: e));
    }
  }

  /// Stores ZenTao [type] [id] (just saved) and returns its ticket id.
  Future<Result<String>> _store(
    String accountId,
    String type,
    String id,
  ) async {
    final client = await _sync.zenTaoClientFor(accountId);
    final host = Uri.tryParse(client?.baseUrl ?? '')?.host ?? '';
    return _sync.fetchZenTaoTicket(host: host, type: type, id: id);
  }

  @override
  Future<Result<BugForm>> newBugForm(String accountId, String productId) =>
      _run(accountId, (f) => f.newBug(productId));

  @override
  Future<Result<BugForm>> editBugForm(String accountId, String bugId) =>
      _run(accountId, (f) => f.editBug(bugId));

  @override
  Future<Result<BugFormOptions>> bugOptions(
    String accountId, {
    required String productId,
    String projectId = '0',
    String executionId = '0',
  }) => _run(
    accountId,
    (f) =>
        f.bugOptions(productId, projectId: projectId, executionId: executionId),
  );

  @override
  Future<Result<String>> saveBug(
    String accountId,
    BugForm form,
    BugDraft draft, {
    required String uid,
  }) async {
    final saved = await _run(accountId, (f) => f.saveBug(form, draft, uid));
    return switch (saved) {
      Ok(:final value) => _store(accountId, 'bug', value),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<TaskForm>> newTaskForm(String accountId, String executionId) =>
      _run(accountId, (f) => f.newTask(executionId));

  @override
  Future<Result<TaskForm>> editTaskForm(String accountId, String taskId) =>
      _run(accountId, (f) => f.editTask(taskId));

  @override
  Future<Result<TaskFormOptions>> taskOptions(
    String accountId,
    String executionId,
  ) => _run(accountId, (f) => f.taskOptions(executionId));

  @override
  Future<Result<String>> saveTask(
    String accountId,
    TaskForm form,
    TaskDraft draft, {
    required String uid,
  }) async {
    final saved = await _run(accountId, (f) => f.saveTask(form, draft, uid));
    return switch (saved) {
      Ok(:final value) => _store(accountId, 'task', value),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Uint8List?> loadImage(String accountId, String url) async =>
      (await _sync.zenTaoClientFor(accountId))?.fetchBytes(url);

  @override
  Future<Result<String>> uploadImage(
    String accountId,
    String uid,
    Uint8List bytes,
    String fileName,
  ) => _run(accountId, (f) => f.uploadImage(uid, bytes, fileName));
}

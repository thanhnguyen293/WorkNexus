import 'package:dio/dio.dart';

import '../../../core/domain/adapters/zentao_workflow_service.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../../../core/domain/value_objects/zentao_action.dart';
import '../../../core/domain/value_objects/zentao_task_action_input.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../connections/data/zentao/zentao_normalize.dart';
import '../../connections/data/zentao/zentao_workflow.dart';
import 'sync_service.dart';

/// [ZenTaoWorkflowService] over each account's pooled ZenTao client.
class ZenTaoWorkflowActions implements ZenTaoWorkflowService {
  const ZenTaoWorkflowActions(this._sync);

  final SyncService _sync;

  @override
  Future<Result<void>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  }) => _sync.confirmBug(ticket, assignee: assignee, comment: comment);

  @override
  Future<Result<void>> activateBug(
    Ticket ticket, {
    String? build,
    String? assignee,
    String? comment,
  }) => _sync.activateBug(
    ticket,
    build: build,
    assignee: assignee,
    comment: comment,
  );

  @override
  Future<Result<void>> closeBug(Ticket ticket, {String? comment}) => _run(
    ticket,
    ticket.copyWith(status: UnifiedStatus.done, providerStatus: 'closed'),
    (w) => w.closeBug(ticket.externalKey, comment: comment),
  );

  @override
  Future<Result<void>> runTaskAction(
    Ticket ticket,
    ZenTaoTaskAction action,
    ZenTaoTaskActionInput input,
  ) {
    final raw = switch (action) {
      ZenTaoTaskAction.start ||
      ZenTaoTaskAction.restart ||
      ZenTaoTaskAction.activate => 'doing',
      ZenTaoTaskAction.pause => 'pause',
      ZenTaoTaskAction.finish => 'done',
      ZenTaoTaskAction.close => 'closed',
      ZenTaoTaskAction.cancel => 'cancel',
    };
    return _run(
      ticket,
      ticket.copyWith(
        status: mapZenTaoStatus(ZenTaoType.task, raw),
        providerStatus: raw,
      ),
      (w) => w.runTaskAction(ticket, action, input),
    );
  }

  Future<Result<void>> _run(
    Ticket ticket,
    Ticket optimistic,
    Future<void> Function(ZenTaoWorkflow workflow) action,
  ) => _sync.runOptimisticAction(ticket, optimistic, () async {
    try {
      final client = await _sync.zenTaoClientFor(ticket.accountId);
      if (client == null) {
        return const Err(AuthFailure('ZenTao account is not signed in'));
      }
      await action(ZenTaoWorkflow(client));
      return const Ok(null);
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (e) {
      // Anything else (an unreadable stored account, a bad server URL) still
      // ends as a failure, so the optimistic change is put back.
      return Err(UnexpectedFailure('ZenTao action failed: $e', cause: e));
    }
  });

  Failure _failureOf(DioException e) {
    final code = e.response?.statusCode ?? 0;
    final message = e.message ?? 'ZenTao request failed';
    if (code == 401 || code == 403) return AuthFailure(message, cause: e);
    // ZenTao answered but refused the action (a field it wants, a state it
    // no longer allows).
    if (e.response != null && code < 400) {
      return ValidationFailure(message, cause: e);
    }
    return NetworkFailure(message, cause: e);
  }
}

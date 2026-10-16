import 'package:dio/dio.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/adapters/zentao_workflow_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/domain/value_objects/zentao_task_action_input.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/sync/data/sync_coordinator.dart';
import '../datasources/zentao_client.dart';
import '../mappers/zentao_normalize.dart';
import '../models/zentao_workflow.dart';

/// [ZenTaoWorkflowService] over each account's pooled ZenTao client.
class ZenTaoWorkflowActions implements ZenTaoWorkflowService {
  const ZenTaoWorkflowActions(this._coordinator);

  final SyncCoordinator _coordinator;

  @override
  Future<Result<void>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  }) {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.todo,
      providerStatus: 'active',
      assignee: assignee ?? ticket.assignee,
    );
    return _runBugAction(
      ticket,
      optimistic,
      (a) => a.confirmBug(ticket, assignee: assignee, comment: comment),
    );
  }

  @override
  Future<Result<void>> activateBug(
    Ticket ticket, {
    String? build,
    String? assignee,
    String? comment,
  }) {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.todo,
      providerStatus: 'active',
      assignee: assignee ?? ticket.assignee,
      labels: _withoutResolution(ticket.labels),
    );
    return _runBugAction(
      ticket,
      optimistic,
      (a) => a.activateBug(
        ticket,
        openedBuild: build,
        assignee: assignee,
        comment: comment,
      ),
    );
  }

  @override
  Future<Result<void>> resolveBug(
    Ticket ticket, {
    required String resolution,
    String? build,
    String? assignee,
    String? comment,
  }) {
    // A resolved bug awaits verification (ZenTao's `resolved` maps to
    // review), and its board column reads the resolution label.
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.review,
      providerStatus: 'resolved',
      assignee: assignee ?? ticket.assignee,
      labels: [
        ..._withoutResolution(ticket.labels),
        'resolution:${resolution.toLowerCase()}',
      ],
    );
    return _runBugAction(
      ticket,
      optimistic,
      (a) => a.resolveBug(
        ticket,
        resolution: resolution,
        resolvedBuild: build,
        assignee: assignee,
        comment: comment,
      ),
    );
  }

  static List<String> _withoutResolution(List<String> labels) => [
    for (final label in labels)
      if (!label.toLowerCase().startsWith('resolution:')) label,
  ];

  Future<Result<void>> _runBugAction(
    Ticket ticket,
    Ticket optimistic,
    Future<Result<bool>> Function(ProviderAdapter adapter) call,
  ) {
    return _coordinator.runOptimisticAction(ticket, optimistic, () async {
      final adapter = await _coordinator.adapterFor(ticket.accountId);
      if (adapter == null) {
        return const Err(AuthFailure('No stored credentials for this account'));
      }
      final res = await call(adapter);
      if (res case Err(:final failure)) return Err(failure);
      return const Ok(null);
    });
  }

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
  ) => _coordinator.runOptimisticAction(ticket, optimistic, () async {
    try {
      final client = await _coordinator.rawClientFor(ticket.accountId);
      if (client is! ZenTaoClient) {
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

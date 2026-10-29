import '../../../../core/data/mappers/mappers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/adapters/zentao_messages_adapter.dart';
import '../../../../core/domain/adapters/zentao_ticket_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/domain/value_objects/zentao_ticket_id.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/util/cancel_signal.dart';
import '../../../../shared/sync/data/sync_coordinator.dart';
import '../../domain/repositories/zentao_task_bugs.dart';
import '../../domain/repositories/zentao_view_pages.dart';
import '../repositories/zentao_adapter.dart';
import 'task_bugs_coverage.dart';

class ZenTaoTicketServiceImpl
    implements ZenTaoTicketService, ZenTaoViewPages, ZenTaoTaskBugs {
  ZenTaoTicketServiceImpl({required this._coordinator});

  final SyncCoordinator _coordinator;

  @override
  Future<Result<String>> fetchZenTaoTicket({
    String? accountId,
    required String host,
    required String type,
    required String id,
  }) async {
    final db = _coordinator.db;
    final rows = await (db.select(
      db.accounts,
    )..where((a) => a.providerType.equals(ProviderType.zentao.name))).get();
    final account = rows
        .map(accountFromRow)
        .where(
          (a) =>
              (accountId != null && a.id == accountId) ||
              Uri.tryParse(a.baseUrl ?? '')?.host == host,
        )
        .firstOrNull;
    final credRef = account?.credentialsRef;
    if (account == null || credRef == null) {
      return const Err(NotFoundFailure('No ZenTao account for this link'));
    }
    final secret = await _coordinator.credentials.read(credRef);
    final adapter = secret == null
        ? null
        : _coordinator.buildAdapter(account, secret);
    if (adapter == null) {
      return const Err(AuthFailure('ZenTao account is not signed in'));
    }
    final stub = Ticket(
      id: zenTaoTicketId(account.id, type, id),
      accountId: account.id,
      projectId: '${account.id}:$type',
      providerType: ProviderType.zentao,
      externalKey: id,
      externalType: '${type[0].toUpperCase()}${type.substring(1)}',
      title: '',
      body: '',
      priority: Priority.medium,
      status: UnifiedStatus.todo,
      providerStatus: '',
      sourceHash: '',
    );
    final detail = await adapter.getTicket(stub);
    switch (detail) {
      case Ok(:final value):
        await db
            .into(db.tickets)
            .insertOnConflictUpdate(ticketToCompanion(value));
        return Ok(value.id);
      case Err(:final failure):
        return Err(failure);
    }
  }

  @override
  Future<Result<List<ProviderProduct>>> listProducts(String accountId) =>
      _coordinator.listProducts(accountId);

  @override
  Future<List<ProviderProduct>?> cachedProducts(String accountId) =>
      _coordinator.cachedProducts(accountId);

  @override
  Future<Result<List<ProviderProject>>> listProjects(String accountId) =>
      _coordinator.listProjects(accountId);

  @override
  Future<List<ProviderProject>?> cachedProjects(String accountId) =>
      _coordinator.cachedProjects(accountId);

  @override
  Future<Result<List<ProviderExecution>>> listProjectExecutions(
    String accountId,
    String projectId,
  ) async {
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    return adapter.listProjectExecutions(projectId);
  }

  /// What recent reads of each execution's bug list covered, by
  /// `accountId:executionId` (see [syncTaskBugs]).
  final _taskBugsCoverage = <String, TaskBugsCoverage>{};

  @override
  Future<Result<ViewPage>> syncProductBugsPage({
    required String accountId,
    required String productId,
    required String browseType,
    required int page,
    required int limit,
    TicketSort sort = TicketSort.newest,
    CancelSignal? cancel,
  }) async {
    final db = _coordinator.db;
    final accountRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProductBugsPage(
      productId,
      browseType: browseType,
      page: page,
      limit: limit,
      sort: sort,
      cancel: cancel,
    );
    if (res case Ok(:final value)) {
      await _coordinator.upsert(account, value.tickets);
    }
    return res;
  }

  @override
  Future<Result<ViewPage>> syncExecutionTasksPage({
    required String accountId,
    required String executionId,
    required String browseType,
    required int page,
    required int limit,
    TicketSort sort = TicketSort.newest,
    CancelSignal? cancel,
  }) async {
    final db = _coordinator.db;
    final accountRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listExecutionTasksPage(
      executionId,
      browseType: browseType,
      page: page,
      limit: limit,
      sort: sort,
      cancel: cancel,
    );
    if (res case Ok(:final value)) {
      await _coordinator.upsert(account, value.tickets);
    }
    return res;
  }

  @override
  Future<Result<void>> syncTaskBugs({
    required String accountId,
    required String executionId,
    required String taskId,
  }) async {
    final task = int.tryParse(taskId);
    if (task == null) return const Ok(null);
    final key = '$accountId:$executionId';
    if (_taskBugsCoverage[key]?.covers(task, DateTime.now()) ?? false) {
      return const Ok(null);
    }
    final db = _coordinator.db;
    final accountRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter is! ZenTaoAdapter) {
      return const Err(AuthFailure('No signed-in ZenTao account'));
    }
    final res = await adapter.listTaskBugs(executionId, taskId: task);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _coordinator.upsert(accountFromRow(accountRow), value.bugs);
        _taskBugsCoverage[key] = TaskBugsCoverage(
          at: DateTime.now(),
          complete: value.complete,
          above: value.above,
          tasks: {task},
        );
        return const Ok(null);
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> fetchZenTaoMessages(
    String accountId,
  ) async {
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter is! ZenTaoMessagesAdapter) {
      return const Err(AuthFailure('No signed-in ZenTao account'));
    }
    return adapter.fetchMessages();
  }

  @override
  Future<Result<void>> zenTaoMessageAction(
    String accountId,
    String action,
  ) async {
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter is! ZenTaoMessagesAdapter) {
      return const Err(AuthFailure('No signed-in ZenTao account'));
    }
    return adapter.messageAction(action);
  }

  @override
  Future<Result<Map<String, dynamic>>> fetchZenTaoUserInfo(
    String accountId, {
    required String fields,
    required int limit,
  }) async {
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter is! ZenTaoMessagesAdapter) {
      return const Err(AuthFailure('No signed-in ZenTao account'));
    }
    return adapter.fetchUserInfo(fields: fields, limit: limit);
  }
}

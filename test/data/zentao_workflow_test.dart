import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_action.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_task_action_input.dart';
import 'package:work_nexus/features/connections/data/zentao/zentao_client.dart';
import 'package:work_nexus/features/connections/data/zentao/zentao_workflow.dart';

class _Fake implements HttpClientAdapter {
  _Fake(this.reply);
  final Object Function(RequestOptions) reply;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(
        options.path.endsWith('/tokens') ? {'token': 't'} : reply(options),
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

final _now = DateTime(2026, 10, 9, 15, 30);

(ZenTaoWorkflow, _Fake) _workflow([Object Function(RequestOptions)? reply]) {
  final fake = _Fake(reply ?? (_) => {'result': 'success'});
  final client = ZenTaoClient(
    baseUrl: 'https://z.example.com/zentao',
    account: 'me',
    password: 'pw',
    dio: Dio()..httpClientAdapter = fake,
  );
  return (ZenTaoWorkflow(client, now: () => _now), fake);
}

Map<String, dynamic> _sent(_Fake fake, String path) =>
    Map.from(fake.requests.lastWhere((r) => r.path.contains(path)).data as Map);

Ticket _task({String? assignee, double? consumed, DateTime? realStarted}) =>
    Ticket(
      id: 'zt:12',
      accountId: 'zt',
      projectId: 'zt:P',
      providerType: ProviderType.zentao,
      externalKey: '12',
      externalType: 'Task',
      title: 't',
      body: '',
      priority: Priority.medium,
      status: UnifiedStatus.todo,
      providerStatus: 'wait',
      sourceHash: 'h',
      assignee: assignee,
      providerEntity: TicketProviderEntity.zentaoTask(
        consumed: consumed,
        realStarted: realStarted,
      ),
    );

void main() {
  test('closing a bug posts its note to bug-close', () async {
    final (workflow, fake) = _workflow();
    await workflow.closeBug('4302', comment: ' verified ');

    final sent = _sent(fake, 'bug-close-4302');
    expect(sent['comment'], 'verified');
    expect(sent.containsKey('uid'), isTrue);
  });

  test('starting sends the new total logged and keeps the assignee', () async {
    final (workflow, fake) = _workflow();
    await workflow.runTaskAction(
      _task(assignee: 'lan', consumed: 2),
      ZenTaoTaskAction.start,
      const ZenTaoTaskActionInput(spent: 1.5, left: 4),
    );

    final sent = _sent(fake, 'task-start-12');
    expect(sent['consumed'], '3.5');
    expect(sent['left'], '4');
    expect(sent['realStarted'], '2026-10-09 15:30:00');
    expect(sent['assignedTo'], 'lan');
    expect(sent.containsKey('comment'), isFalse);
  });

  test('continuing keeps when the task really started', () async {
    final (workflow, fake) = _workflow();
    await workflow.runTaskAction(
      _task(realStarted: DateTime(2026, 10, 1, 9)),
      ZenTaoTaskAction.restart,
      const ZenTaoTaskActionInput(left: 2, assignee: 'an'),
    );

    final sent = _sent(fake, 'task-restart-12');
    expect(sent['realStarted'], '2026-10-01 09:00:00');
    expect(sent['assignedTo'], 'an');
  });

  test('finishing sends this time and the total, dated now', () async {
    final (workflow, fake) = _workflow();
    await workflow.runTaskAction(
      _task(consumed: 3, realStarted: DateTime(2026, 10, 8, 10)),
      ZenTaoTaskAction.finish,
      const ZenTaoTaskActionInput(spent: 2, comment: 'done'),
    );

    final sent = _sent(fake, 'task-finish-12');
    expect(sent['currentConsumed'], '2');
    expect(sent['consumed'], '5');
    expect(sent['realStarted'], '2026-10-08 10:00:00');
    expect(sent['finishedDate'], '2026-10-09 15:30:00');
    expect(sent['comment'], 'done');
    // Left out, ZenTao hands the task back to its creator.
    expect(sent.containsKey('assignedTo'), isFalse);
    expect(sent.containsKey('left'), isFalse);
  });

  test('reopening sends the hours left and gives the task to me', () async {
    final (workflow, fake) = _workflow();
    await workflow.runTaskAction(
      _task(),
      ZenTaoTaskAction.activate,
      const ZenTaoTaskActionInput(left: 1),
    );

    final sent = _sent(fake, 'task-activate-12');
    expect(sent['left'], '1');
    expect(sent['assignedTo'], 'me');
  });

  test('pause, close and cancel send only a note', () async {
    for (final action in [
      ZenTaoTaskAction.pause,
      ZenTaoTaskAction.close,
      ZenTaoTaskAction.cancel,
    ]) {
      final (workflow, fake) = _workflow();
      await workflow.runTaskAction(
        _task(consumed: 1),
        action,
        const ZenTaoTaskActionInput(spent: 9, left: 9, comment: 'why'),
      );

      final sent = _sent(fake, 'task-${action.name}-12');
      expect(sent.keys.toSet(), {'uid', 'comment'}, reason: action.name);
    }
  });

  test('a refusal wrapped the 18.x way still fails, with its reason', () async {
    // 18.x wraps every .json reply as {status: success, data: '<json>'} — a
    // refused action too.
    final (workflow, _) = _workflow(
      (_) => {
        'status': 'success',
        'data': jsonEncode({
          'result': 'fail',
          'message': {
            'left': ['Left must be more than 0'],
          },
        }),
      },
    );

    await expectLater(
      workflow.runTaskAction(
        _task(),
        ZenTaoTaskAction.activate,
        const ZenTaoTaskActionInput(left: 1),
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.message,
          'message',
          contains('Left must be more than 0'),
        ),
      ),
    );
  });

  test('an 18.x success (a page to go to) passes', () async {
    final (workflow, _) = _workflow(
      (_) => {
        'status': 'success',
        'data': jsonEncode({'locate': '/zentao/task-view-12.html'}),
      },
    );

    await workflow.runTaskAction(
      _task(),
      ZenTaoTaskAction.pause,
      const ZenTaoTaskActionInput(),
    );
  });

  test('a 20+ refusal fails', () async {
    final (workflow, _) = _workflow(
      (_) => {'result': 'fail', 'message': 'Task is already started'},
    );

    await expectLater(
      workflow.runTaskAction(
        _task(),
        ZenTaoTaskAction.start,
        const ZenTaoTaskActionInput(left: 1),
      ),
      throwsA(isA<DioException>()),
    );
  });

  test('hours are sent as ZenTao writes them', () {
    expect(zentaoHours(2), '2');
    expect(zentaoHours(2.5), '2.5');
    expect(zentaoHours(0.1 + 0.2), '0.3');
  });
}

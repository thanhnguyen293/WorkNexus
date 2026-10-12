import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/adapters/zentao_ticket_service.dart';
import 'package:work_nexus/core/domain/usecases/resolve_zentao_ticket.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';

class _MockService extends Mock implements ZenTaoTicketService {}

void main() {
  late _MockService service;

  setUp(() => service = _MockService());

  void verifyNoFetch() => verifyNever(
    () => service.fetchZenTaoTicket(
      host: any(named: 'host'),
      type: any(named: 'type'),
      id: any(named: 'id'),
    ),
  );

  test('a synced ticket resolves without asking ZenTao', () async {
    final resolve = ResolveZenTaoTicket(
      service,
      isSynced: (id) => id == 'zt:task:42',
    );

    final res = await resolve(
      accountId: 'zt',
      host: 'zentao.example.com',
      type: 'task',
      id: '42',
    );

    expect(
      res,
      isA<Ok<String>>().having((r) => r.value, 'value', 'zt:task:42'),
    );
    verifyNoFetch();
  });

  test('an unsynced ticket is fetched from its host', () async {
    when(
      () => service.fetchZenTaoTicket(
        host: 'zentao.example.com',
        type: 'bug',
        id: '7',
      ),
    ).thenAnswer((_) async => const Ok('zt:bug:7'));
    final resolve = ResolveZenTaoTicket(service, isSynced: (_) => false);

    final res = await resolve(
      accountId: 'zt',
      host: 'zentao.example.com',
      type: 'bug',
      id: '7',
    );

    expect(res, isA<Ok<String>>().having((r) => r.value, 'value', 'zt:bug:7'));
  });

  test('without an account the ticket is always fetched', () async {
    when(
      () => service.fetchZenTaoTicket(
        host: 'zentao.example.com',
        type: 'story',
        id: '3',
      ),
    ).thenAnswer((_) async => const Ok('zt:story:3'));
    final resolve = ResolveZenTaoTicket(service, isSynced: (_) => true);

    final res = await resolve(
      host: 'zentao.example.com',
      type: 'story',
      id: '3',
    );

    expect(res, isA<Ok<String>>());
  });

  test('an unsynced ticket with no host fails without a fetch', () async {
    final resolve = ResolveZenTaoTicket(service, isSynced: (_) => false);

    final res = await resolve(accountId: 'zt', host: '', type: 'task', id: '1');

    expect(
      res,
      isA<Err<String>>().having(
        (r) => r.failure,
        'failure',
        isA<NotFoundFailure>(),
      ),
    );
    verifyNoFetch();
  });
}

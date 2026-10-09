import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:work_nexus/features/dashboard/data/mappers/zentao_dashboard_mapper.dart';
import 'package:work_nexus/features/dashboard/data/repositories/zentao_dashboard_repository.dart';

final _fetchedAt = DateTime(2026, 10, 9, 12);

void main() {
  late AppDatabase db;
  late Result<Map<String, dynamic>> reply;
  late List<(String, String, int)> calls;
  late ZenTaoDashboardRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    calls = [];
    reply = const Ok({
      'profile': {'account': 'thanh', 'realname': 'Thanh'},
      'bug': {
        'total': 2,
        'bugs': [
          {'id': 1, 'title': 'One'},
        ],
      },
    });
    repository = ZenTaoDashboardRepository(
      local: DashboardLocalDatasource(db),
      fetch: (accountId, {required fields, required limit}) async {
        calls.add((accountId, fields, limit));
        return reply;
      },
      syncAssigned: (_) async => const Ok(0),
      now: () => _fetchedAt,
    );
  });

  tearDown(() => db.close());

  test('nothing is stored before the first refresh', () async {
    expect(await repository.cached('a1'), isNull);
  });

  test('refresh asks for the dashboard fields and stores the reply', () async {
    final res = await repository.refresh('a1');

    expect(res.isOk, isTrue);
    expect(calls, [('a1', kZenTaoDashboardFields, kZenTaoDashboardListLimit)]);
    final stored = await repository.cached('a1');
    expect(stored?.profile.realname, 'Thanh');
    expect(stored?.bugTotal, 2);
    expect(stored?.bugs.single.title, 'One');
    expect(stored?.fetchedAt, _fetchedAt);
  });

  test('watch emits the stored dashboard after a refresh', () async {
    final emitted = repository.watch('a1').where((d) => d != null).first;
    await repository.refresh('a1');

    expect((await emitted)?.profile.account, 'thanh');
  });

  test('a failed fetch is returned and keeps the stored snapshot', () async {
    await repository.refresh('a1');
    reply = const Err(NetworkFailure('offline'));

    final res = await repository.refresh('a1');

    expect(res.failureOrNull, isA<NetworkFailure>());
    expect((await repository.cached('a1'))?.bugTotal, 2);
  });
}

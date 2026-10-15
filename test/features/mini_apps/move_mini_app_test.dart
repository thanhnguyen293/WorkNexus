import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';
import 'package:work_nexus/features/mini_apps/domain/repositories/mini_app_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/move_mini_app.dart';

class _MockRepo extends Mock implements MiniAppRepository {}

const _apps = [
  MiniApp(id: 'a', name: 'A', url: 'https://a.io', position: 0),
  MiniApp(id: 'b', name: 'B', url: 'https://b.io', position: 1),
  MiniApp(id: 'c', name: 'C', url: 'https://c.io', position: 2),
];

List<String> _ids(List<MiniApp> apps) => [for (final a in apps) a.id];

void main() {
  late _MockRepo repo;
  setUp(() {
    repo = _MockRepo();
    when(() => repo.saveOrder(any())).thenAnswer((_) async => const Ok(null));
  });

  test('moves down to the index it ends at and keeps the order', () async {
    final res = await MoveMiniApp(repo)(_apps, from: 0, to: 2);
    expect(_ids(res.valueOrNull!), ['b', 'c', 'a']);
    expect([for (final a in res.valueOrNull!) a.position], [0, 1, 2]);
    verify(() => repo.saveOrder(['b', 'c', 'a'])).called(1);
  });

  test('moves up', () async {
    final res = await MoveMiniApp(repo)(_apps, from: 2, to: 0);
    expect(_ids(res.valueOrNull!), ['c', 'a', 'b']);
  });

  test('a move that goes nowhere saves nothing', () async {
    await MoveMiniApp(repo)(_apps, from: 1, to: 1);
    await MoveMiniApp(repo)(_apps, from: 0, to: 3);
    verifyNever(() => repo.saveOrder(any()));
  });

  test('passes on a failed save', () async {
    when(
      () => repo.saveOrder(any()),
    ).thenAnswer((_) async => const Err(StorageFailure('x')));
    final res = await MoveMiniApp(repo)(_apps, from: 0, to: 1);
    expect(res.failureOrNull, isA<StorageFailure>());
  });
}

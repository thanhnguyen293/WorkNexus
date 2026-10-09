import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/dashboard/domain/entities/dashboard_profile.dart';
import 'package:work_nexus/features/dashboard/domain/entities/zentao_dashboard.dart';
import 'package:work_nexus/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:work_nexus/features/dashboard/domain/usecases/refresh_dashboard.dart';

class _MockDashboardRepository extends Mock implements DashboardRepository {}

final _now = DateTime(2026, 10, 9, 12);

ZenTaoDashboard _fetchedAt(DateTime at) => ZenTaoDashboard(
  accountId: 'a1',
  profile: const DashboardProfile(account: 'thanh', realname: 'Thanh'),
  fetchedAt: at,
);

void main() {
  late _MockDashboardRepository repository;
  late RefreshDashboard refresh;

  setUp(() {
    repository = _MockDashboardRepository();
    refresh = RefreshDashboard(repository, now: () => _now);
    when(
      () => repository.refresh('a1'),
    ).thenAnswer((_) async => const Ok(null));
  });

  test('fetches when nothing is stored yet', () async {
    when(() => repository.cached('a1')).thenAnswer((_) async => null);

    expect((await refresh('a1')).isOk, isTrue);
    verify(() => repository.refresh('a1')).called(1);
  });

  test('keeps a snapshot younger than maxAge', () async {
    when(() => repository.cached('a1')).thenAnswer(
      (_) async => _fetchedAt(_now.subtract(const Duration(minutes: 2))),
    );

    expect((await refresh('a1')).isOk, isTrue);
    verifyNever(() => repository.refresh(any()));
  });

  test('fetches a snapshot older than maxAge', () async {
    when(() => repository.cached('a1')).thenAnswer(
      (_) async => _fetchedAt(_now.subtract(const Duration(minutes: 6))),
    );

    await refresh('a1');
    verify(() => repository.refresh('a1')).called(1);
  });

  test('force fetches without looking at the stored snapshot', () async {
    await refresh('a1', force: true);

    verifyNever(() => repository.cached(any()));
    verify(() => repository.refresh('a1')).called(1);
  });

  test('passes the repository failure through', () async {
    when(() => repository.cached('a1')).thenAnswer((_) async => null);
    when(
      () => repository.refresh('a1'),
    ).thenAnswer((_) async => const Err(AuthFailure('expired')));

    final res = await refresh('a1');
    expect(res.failureOrNull, isA<AuthFailure>());
  });
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/favicon_fetcher.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/mini_app_icon_storage.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/mini_app_local_datasource.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/mini_app_permission_local_datasource.dart';
import 'package:work_nexus/features/mini_apps/data/repositories/local_mini_app_permission_repository.dart';
import 'package:work_nexus/features/mini_apps/data/repositories/local_mini_app_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app_permission.dart';
import 'package:work_nexus/features/mini_apps/domain/repositories/mini_app_permission_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/resolve_mini_app_permission.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/mini_app_providers.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/mini_app_notifications.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/mini_app_permission_kind.dart';

class _MockRepo extends Mock implements MiniAppPermissionRepository {}

const _allow = MiniAppPermissionDecision.allow;
const _block = MiniAppPermissionDecision.block;

void main() {
  group('ResolveMiniAppPermission', () {
    late _MockRepo repo;
    setUp(() => repo = _MockRepo());

    void stub(MiniAppPermissionKind kind, MiniAppPermissionDecision? d) =>
        when(() => repo.decisionFor('a', kind)).thenAnswer((_) async => Ok(d));

    test('asks (null) when nothing is remembered', () async {
      stub(MiniAppPermissionKind.camera, null);
      expect(
        await ResolveMiniAppPermission(repo)('a', [
          MiniAppPermissionKind.camera,
        ]),
        isNull,
      );
    });

    test('answers with the remembered choice', () async {
      stub(MiniAppPermissionKind.camera, _allow);
      expect(
        await ResolveMiniAppPermission(repo)('a', [
          MiniAppPermissionKind.camera,
        ]),
        _allow,
      );
    });

    test('allows several kinds only when all are allowed', () async {
      stub(MiniAppPermissionKind.camera, _allow);
      stub(MiniAppPermissionKind.microphone, _block);
      expect(
        await ResolveMiniAppPermission(repo)('a', [
          MiniAppPermissionKind.camera,
          MiniAppPermissionKind.microphone,
        ]),
        _block,
      );
    });

    test('asks when any of several kinds was never answered', () async {
      stub(MiniAppPermissionKind.camera, _allow);
      stub(MiniAppPermissionKind.microphone, null);
      expect(
        await ResolveMiniAppPermission(repo)('a', [
          MiniAppPermissionKind.camera,
          MiniAppPermissionKind.microphone,
        ]),
        isNull,
      );
    });
  });

  group('MiniAppPermissionController', () {
    late _MockRepo repo;
    late ProviderContainer container;
    setUpAll(
      () => registerFallbackValue(
        const MiniAppPermissionGrant(
          miniAppId: 'a',
          kind: MiniAppPermissionKind.other,
          decision: _block,
        ),
      ),
    );
    setUp(() {
      repo = _MockRepo();
      container = ProviderContainer(
        overrides: [
          miniAppPermissionRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
    });

    MiniAppPermissionController controller() =>
        container.read(miniAppPermissionControllerProvider.notifier);

    test('remember reports a failure instead of dropping it', () async {
      when(() => repo.save(any())).thenAnswer(
        (inv) async =>
            (inv.positionalArguments.first as MiniAppPermissionGrant).kind ==
                MiniAppPermissionKind.microphone
            ? const Err(StorageFailure('disk full'))
            : const Ok(null),
      );
      final res = await controller().remember('a', const [
        MiniAppPermissionKind.camera,
        MiniAppPermissionKind.microphone,
      ], _allow);
      expect(res.failureOrNull, isA<StorageFailure>());
      verify(() => repo.save(any())).called(2);
    });

    test('forget passes the result through', () async {
      when(
        () => repo.clear('a', MiniAppPermissionKind.camera),
      ).thenAnswer((_) async => const Err(StorageFailure('locked')));
      final res = await controller().forget('a', MiniAppPermissionKind.camera);
      expect(res.isErr, isTrue);
    });
  });

  group('local repositories', () {
    late AppDatabase db;
    late LocalMiniAppPermissionRepository permissions;
    late LocalMiniAppRepository apps;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      permissions = LocalMiniAppPermissionRepository(
        MiniAppPermissionLocalDatasource(db),
      );
      apps = LocalMiniAppRepository(
        MiniAppLocalDatasource(db),
        MiniAppIconStorage(() async => Directory.systemTemp),
        FaviconFetcher(),
      );
    });
    tearDown(() => db.close());

    const grant = MiniAppPermissionGrant(
      miniAppId: 'a',
      kind: MiniAppPermissionKind.notifications,
      decision: _allow,
    );

    test('remembers, changes and forgets an answer', () async {
      await permissions.save(grant);
      expect(
        (await permissions.decisionFor('a', grant.kind)).valueOrNull,
        _allow,
      );
      await permissions.save(grant.copyWith(decision: _block));
      expect(
        (await permissions.decisionFor('a', grant.kind)).valueOrNull,
        _block,
      );
      await permissions.clear('a', grant.kind);
      expect(
        (await permissions.decisionFor('a', grant.kind)).valueOrNull,
        null,
      );
    });

    test('keeps answers per app', () async {
      await permissions.save(grant);
      expect(
        (await permissions.decisionFor('b', grant.kind)).valueOrNull,
        isNull,
      );
    });

    test('watch emits the app\'s answers as they change', () async {
      final seen = <int>[];
      final sub = permissions.watch('a').listen((g) => seen.add(g.length));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await permissions.save(grant);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();
      expect(seen, [0, 1]);
    });

    test('removing an app removes its answers', () async {
      await apps.save(
        const MiniApp(id: 'a', name: 'A', url: 'https://a.io', position: 0),
      );
      await permissions.save(grant);
      await apps.delete('a');
      expect(
        (await permissions.decisionFor('a', grant.kind)).valueOrNull,
        null,
      );
    });
  });

  group('web view permission kinds', () {
    test('map to the app\'s kinds', () {
      expect(miniAppPermissionKindsOf(PermissionResourceType.NOTIFICATIONS), [
        MiniAppPermissionKind.notifications,
      ]);
      expect(
        miniAppPermissionKindsOf(PermissionResourceType.CAMERA_AND_MICROPHONE),
        [MiniAppPermissionKind.camera, MiniAppPermissionKind.microphone],
      );
      expect(miniAppPermissionKindsOf(PermissionResourceType.UNKNOWN), [
        MiniAppPermissionKind.other,
      ]);
    });
  });

  test('a notification payload finds its mini app again', () {
    expect(
      miniAppIdOfNotificationPayload(miniAppNotificationPayload('abc')),
      'abc',
    );
    expect(miniAppIdOfNotificationPayload('{"a":"1","c":"2"}'), isNull);
  });
}

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/data/repositories/settings_sync_status_repository.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/di/locator.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/github_pr_service.dart';
import 'package:work_nexus/core/domain/adapters/gitlab_mr_service.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter_registry.dart';
import 'package:work_nexus/core/domain/adapters/zentao_ticket_service.dart';
import 'package:work_nexus/core/domain/repositories/sync_status_repository.dart';
import 'package:work_nexus/core/domain/value_objects/account_sync_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/platform/credential_store.dart';
import 'package:work_nexus/shared/sync/data/sync_service.dart';

class MockGitLabMrService extends Mock implements GitLabMrService {}

class MockGitHubPrService extends Mock implements GitHubPrService {}

class MockZenTaoTicketService extends Mock implements ZenTaoTicketService {}

class MockCredentialStore extends Mock implements CredentialStore {}

class MockProviderAdapterRegistry extends Mock
    implements ProviderAdapterRegistry {}

class MockSyncStatusRepository extends Mock implements SyncStatusRepository {}

void main() {
  group('SettingsSyncStatusRepository', () {
    late AppDatabase db;
    late SettingsSyncStatusRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = SettingsSyncStatusRepository(db);
    });

    tearDown(() async {
      repository.dispose();
      await db.close();
    });

    test(
      'getStatus returns default idle with null lastSyncedAt when unset',
      () async {
        final status = await repository.getStatus('acc_1');
        expect(status, equals(const AccountSyncStatus.idle()));
      },
    );

    test(
      'report persists idle lastSyncedAt and getStatus retrieves it',
      () async {
        final now = DateTime(2026, 10, 14, 12);
        repository.report('acc_1', AccountSyncStatus.idle(lastSyncedAt: now));

        // Wait a microtask for async SQLite insert
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Clear memory cache to ensure it reads from SQLite
        final freshRepo = SettingsSyncStatusRepository(db);
        final status = await freshRepo.getStatus('acc_1');
        expect(status, equals(AccountSyncStatus.idle(lastSyncedAt: now)));
        freshRepo.dispose();
      },
    );

    test(
      'watch emits initial state and subsequent reported statuses',
      () async {
        final now = DateTime(2026, 10, 14, 13);
        final stream = repository.watch('acc_2');

        final emitted = <AccountSyncStatus>[];
        final sub = stream.listen(emitted.add);

        // Initial read
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(emitted, [const AccountSyncStatus.idle()]);

        // Report syncing
        repository.report('acc_2', const AccountSyncStatus.syncing());
        // Report authExpired
        repository.report('acc_2', const AccountSyncStatus.authExpired());
        // Report idle with timestamp
        repository.report('acc_2', AccountSyncStatus.idle(lastSyncedAt: now));

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(emitted, [
          const AccountSyncStatus.idle(),
          const AccountSyncStatus.syncing(),
          const AccountSyncStatus.authExpired(),
          AccountSyncStatus.idle(lastSyncedAt: now),
        ]);

        await sub.cancel();
      },
    );
  });

  group('SyncService sync tracking with mock adapters', () {
    late AppDatabase db;
    late MockCredentialStore credentials;
    late MockProviderAdapterRegistry registry;
    late MockGitLabMrService gitlab;
    late MockGitHubPrService github;
    late MockZenTaoTicketService zentao;
    late MockSyncStatusRepository statusRepo;
    late SyncService syncService;

    setUpAll(() {
      registerFallbackValue(const AccountSyncStatus.idle());
    });

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      credentials = MockCredentialStore();
      registry = MockProviderAdapterRegistry();
      gitlab = MockGitLabMrService();
      github = MockGitHubPrService();
      zentao = MockZenTaoTicketService();
      statusRepo = MockSyncStatusRepository();

      syncService = SyncService(
        db,
        credentials,
        registry: registry,
        gitlabMrService: gitlab,
        githubPrService: github,
        zentaoTicketService: zentao,
        statusRepository: statusRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('a 401 AuthFailure reports syncing then authExpired', () async {
      when(
        () => gitlab.syncGitLabProjectItems(
          accountId: 'gl_acc_1',
          projectId: 'p_1',
          mergeRequests: true,
        ),
      ).thenAnswer(
        (_) async => const Err(AuthFailure('GitLab authentication failed')),
      );

      final result = await syncService.syncGitLabProjectItems(
        accountId: 'gl_acc_1',
        projectId: 'p_1',
        mergeRequests: true,
      );

      expect(result.isErr, isTrue);

      verifyInOrder([
        () => statusRepo.report('gl_acc_1', const AccountSyncStatus.syncing()),
        () => statusRepo.report(
          'gl_acc_1',
          const AccountSyncStatus.authExpired(),
        ),
      ]);
    });

    test('a NetworkFailure reports syncing then offline', () async {
      when(() => gitlab.syncGitLabMine('gl_acc_1')).thenAnswer(
        (_) async => const Err(NetworkFailure('Connection timed out')),
      );

      final result = await syncService.syncGitLabMine('gl_acc_1');

      expect(result.isErr, isTrue);

      verifyInOrder([
        () => statusRepo.report('gl_acc_1', const AccountSyncStatus.syncing()),
        () => statusRepo.report('gl_acc_1', const AccountSyncStatus.offline()),
      ]);
    });

    test(
      'a SocketException reports syncing then offline and rethrows',
      () async {
        when(
          () => github.syncGitHubMine('gh_acc_1'),
        ).thenThrow(const SocketException('Failed host lookup'));

        await expectLater(
          syncService.syncGitHubMine('gh_acc_1'),
          throwsA(isA<SocketException>()),
        );

        verifyInOrder([
          () =>
              statusRepo.report('gh_acc_1', const AccountSyncStatus.syncing()),
          () =>
              statusRepo.report('gh_acc_1', const AccountSyncStatus.offline()),
        ]);
      },
    );

    test('success reports syncing then idle with lastSyncedAt', () async {
      when(
        () => github.syncGitHubRepoItems(
          accountId: 'gh_acc_1',
          repoId: 'repo_1',
          pullRequests: true,
        ),
      ).thenAnswer((_) async => const Ok(['pr_1', 'pr_2']));

      final result = await syncService.syncGitHubRepoItems(
        accountId: 'gh_acc_1',
        repoId: 'repo_1',
        pullRequests: true,
      );

      expect(result.isOk, isTrue);

      verify(
        () => statusRepo.report('gh_acc_1', const AccountSyncStatus.syncing()),
      ).called(1);
      final captured = verify(
        () => statusRepo.report('gh_acc_1', captureAny()),
      ).captured;

      expect(captured.last, isA<SyncIdle>());
      final idle = captured.last as SyncIdle;
      expect(idle.lastSyncedAt, isNotNull);
    });
  });

  group('syncStatusProvider Riverpod integration', () {
    test('syncStatusProvider reads from SyncStatusRepository in DI', () async {
      final mockRepo = MockSyncStatusRepository();
      when(
        () => mockRepo.watch('acc_test'),
      ).thenAnswer((_) => Stream.value(const AccountSyncStatus.syncing()));

      if (getIt.isRegistered<SyncStatusRepository>()) {
        getIt.unregister<SyncStatusRepository>();
      }
      getIt.registerSingleton<SyncStatusRepository>(mockRepo);
      addTearDown(() {
        if (getIt.isRegistered<SyncStatusRepository>()) {
          getIt.unregister<SyncStatusRepository>();
        }
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final completer = Completer<AccountSyncStatus>();
      final sub = container.listen<AsyncValue<AccountSyncStatus>>(
        syncStatusProvider('acc_test'),
        (previous, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete(next.value);
          }
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final val = await completer.future.timeout(const Duration(seconds: 1));
      expect(val, equals(const AccountSyncStatus.syncing()));
    });
  });
}

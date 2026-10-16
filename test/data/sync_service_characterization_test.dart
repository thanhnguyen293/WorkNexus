import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter_registry.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/platform/credential_store.dart';
import 'package:work_nexus/shared/sync/data/attachment_file_cache.dart';
import 'package:work_nexus/shared/sync/data/sync_coordinator.dart';
import 'package:work_nexus/tools/github/data/services/github_pr_service_impl.dart';
import 'package:work_nexus/tools/gitlab/data/services/gitlab_mr_service_impl.dart';
import 'package:work_nexus/tools/zentao/data/services/zentao_workflow_actions.dart';

class _MemoryCredentialStore extends CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String ref) async => values[ref];

  @override
  Future<void> write(String ref, String secret) async => values[ref] = secret;
}

class _FakeProviderAdapterRegistry implements ProviderAdapterRegistry {
  @override
  ProviderAdapter? createAdapter(
    Account account,
    String secret, {
    dynamic zenClient,
  }) => null;
}

void main() {
  group('Sync characterization tests', () {
    late AppDatabase db;
    late _MemoryCredentialStore credentials;
    late Directory tempCacheDir;
    late AttachmentFileCache attachmentCache;
    late SyncCoordinator coordinator;
    late GitLabMrServiceImpl gitlab;
    late GitHubPrServiceImpl github;
    late ZenTaoWorkflowActions workflow;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      credentials = _MemoryCredentialStore();
      tempCacheDir = Directory.systemTemp.createTempSync(
        'sync_service_char_test_',
      );
      attachmentCache = AttachmentFileCache(root: tempCacheDir);
      coordinator = SyncCoordinator(
        db,
        credentials,
        registry: _FakeProviderAdapterRegistry(),
        attachmentCache: attachmentCache,
      );
      gitlab = GitLabMrServiceImpl(coordinator);
      github = GitHubPrServiceImpl(coordinator);
      workflow = ZenTaoWorkflowActions(coordinator);
    });

    tearDown(() async {
      await db.close();
      if (tempCacheDir.existsSync()) {
        tempCacheDir.deleteSync(recursive: true);
      }
    });

    group('Group 1: Account sync', () {
      test(
        'syncAccount returns AuthFailure when credentialsRef is null',
        () async {
          const account = Account(
            id: 'acc-no-cred',
            workspaceId: 'ws-1',
            providerType: ProviderType.zentao,
            handle: 'ZenTao Account',
            baseUrl: 'http://zentao.local',
          );

          final result = await coordinator.syncAccount(account);
          expect(result, isA<Err<int>>());
          expect((result as Err<int>).failure, isA<AuthFailure>());
          expect(result.failure.message, contains('No stored credentials'));
        },
      );

      test(
        'syncAccount returns AuthFailure when secret not in credential store',
        () async {
          const account = Account(
            id: 'acc-missing-secret',
            workspaceId: 'ws-1',
            providerType: ProviderType.zentao,
            handle: 'ZenTao Account',
            baseUrl: 'http://zentao.local',
            credentialsRef: 'missing-key',
          );

          final result = await coordinator.syncAccount(account);
          expect(result, isA<Err<int>>());
          expect((result as Err<int>).failure, isA<AuthFailure>());
          expect(result.failure.message, contains('not found in keychain'));
        },
      );
    });

    group('Group 2: ZenTao bug/task actions', () {
      const zentaoTicket = Ticket(
        id: 'zentao:bug:123',
        accountId: 'acc-zentao-1',
        projectId: 'proj-1',
        providerType: ProviderType.zentao,
        externalKey: '123',
        externalType: 'bug',
        title: 'ZenTao Test Bug',
        body: 'Bug body',
        priority: Priority.high,
        status: UnifiedStatus.todo,
        providerStatus: 'active',
        sourceHash: 'hash-123',
      );

      test(
        'confirmBug fails gracefully with AuthFailure when account not configured',
        () async {
          final result = await workflow.confirmBug(
            zentaoTicket,
            assignee: 'user1',
            comment: 'Confirming bug',
          );
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );

      test(
        'resolveBug fails gracefully with AuthFailure when account not configured',
        () async {
          final result = await workflow.resolveBug(
            zentaoTicket,
            resolution: 'bydesign',
            comment: 'Resolved',
          );
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );

      test(
        'activateBug fails gracefully with AuthFailure when account not configured',
        () async {
          final result = await workflow.activateBug(
            zentaoTicket,
            build: 'trunk',
            comment: 'Reopening bug',
          );
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );
    });

    group('Group 3: GitLab MR actions', () {
      const gitlabTicket = Ticket(
        id: 'gitlab:mr:456',
        accountId: 'acc-gitlab-1',
        projectId: 'project-gl-1',
        providerType: ProviderType.gitlab,
        externalKey: '456',
        externalType: 'mr',
        title: 'GitLab Test MR',
        body: 'MR description',
        priority: Priority.medium,
        status: UnifiedStatus.inprogress,
        providerStatus: 'opened',
        sourceHash: 'hash-456',
      );

      test(
        'closeGitLabItem returns AuthFailure when account not found',
        () async {
          final result = await gitlab.closeGitLabItem(gitlabTicket);
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );

      test(
        'reopenGitLabItem returns AuthFailure when account not found',
        () async {
          final result = await gitlab.reopenGitLabItem(gitlabTicket);
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );

      test(
        'mergeGitLabMr returns AuthFailure when account not found',
        () async {
          final result = await gitlab.mergeGitLabMr(gitlabTicket);
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );

      test(
        'approveGitLabMr returns AuthFailure when account not found',
        () async {
          final result = await gitlab.approveGitLabMr(gitlabTicket);
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );
    });

    group('Group 4: GitHub PR actions', () {
      const githubTicket = Ticket(
        id: 'github:pr:789',
        accountId: 'acc-github-1',
        projectId: 'repo-gh-1',
        providerType: ProviderType.github,
        externalKey: '789',
        externalType: 'pr',
        title: 'GitHub Test PR',
        body: 'PR description',
        priority: Priority.low,
        status: UnifiedStatus.inprogress,
        providerStatus: 'open',
        sourceHash: 'hash-789',
      );

      test(
        'closeGitHubItem returns AuthFailure when account not found',
        () async {
          final result = await github.closeGitHubItem(githubTicket);
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );

      test(
        'reopenGitHubItem returns AuthFailure when account not found',
        () async {
          final result = await github.reopenGitHubItem(githubTicket);
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );

      test(
        'mergeGitHubPr returns AuthFailure when account not found',
        () async {
          final result = await github.mergeGitHubPr(githubTicket);
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );

      test(
        'updateGitHubPrBranch returns AuthFailure when account not found',
        () async {
          final result = await github.updateGitHubPrBranch(githubTicket);
          expect(result, isA<Err<void>>());
          expect((result as Err<void>).failure, isA<AuthFailure>());
        },
      );
    });

    group('Group 5: Attachments', () {
      const ticket = Ticket(
        id: 'zentao:bug:123',
        accountId: 'acc-zentao-1',
        projectId: 'proj-1',
        providerType: ProviderType.zentao,
        externalKey: '123',
        externalType: 'bug',
        title: 'ZenTao Test Bug',
        body: 'Bug body',
        priority: Priority.high,
        status: UnifiedStatus.todo,
        providerStatus: 'active',
        sourceHash: 'hash-123',
      );

      const attachment = TicketAttachment(
        id: 'att-1',
        title: 'screenshot.png',
        url: 'http://zentao.local/file-1.png',
      );

      test('purgeAttachmentCache executes without error', () async {
        await expectLater(coordinator.purgeAttachmentCache(), completes);
      });

      test(
        'cacheAttachment returns null when account has no credentials',
        () async {
          final cachedPath = await coordinator.cacheAttachment(
            ticket,
            attachment,
          );
          expect(cachedPath, isNull);
        },
      );
    });
  });
}

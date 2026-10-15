import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/data/repositories/settings_nav_location_store.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/tools/tool_module.dart';
import 'package:work_nexus/tools/github/github_module.dart';
import 'package:work_nexus/tools/zentao/zentao_module.dart';

void main() {
  group('AppNavState & NavLocationPayload JSON serialization', () {
    test('A JSON round-trip works', () {
      const payload = NavLocationPayload(
        rail: RailTarget.account('acc_1'),
        workspaceSection: WorkspaceSection.integrations,
        locations: {
          'acc_1': ToolLocation(
            section: SectionId('zentao.tasks'),
            scopeId: 'project_42',
            quickScope: QuickScope.assignedToMe,
            viewModes: {SectionId('zentao.tasks'): ViewModeId('kanban')},
            recentScopeIds: ['project_42', 'project_10'],
          ),
        },
      );

      final jsonMap = payload.toJson();
      final jsonString = jsonEncode(jsonMap);
      final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = NavLocationPayload.fromJson(decodedMap);

      expect(restored.version, equals(1));
      expect(restored.rail, equals(const RailTarget.account('acc_1')));
      expect(restored.workspaceSection, equals(WorkspaceSection.integrations));
      expect(restored.locations.containsKey('acc_1'), isTrue);

      final loc = restored.locations['acc_1']!;
      expect(loc.section, equals(const SectionId('zentao.tasks')));
      expect(loc.scopeId, equals('project_42'));
      expect(loc.quickScope, equals(QuickScope.assignedToMe));
      expect(
        loc.viewModes[const SectionId('zentao.tasks')],
        equals(const ViewModeId('kanban')),
      );
      expect(loc.recentScopeIds, equals(['project_42', 'project_10']));
    });

    test('a corrupt or old-version payload yields the default state', () {
      // Version mismatch
      final oldVersionJson = {
        'version': 0,
        'rail': {'kind': 'account', 'accountId': 'acc_1'},
        'workspaceSection': 'settings',
      };
      final oldResult = NavLocationPayload.fromJson(oldVersionJson);
      expect(oldResult.version, equals(NavLocationPayload.kNavLocationVersion));
      expect(oldResult.rail, equals(const RailTarget.workspace()));
      expect(oldResult.workspaceSection, equals(WorkspaceSection.overview));
      expect(oldResult.locations, isEmpty);

      // Future/unsupported version
      final futureVersionJson = {
        'version': 999,
        'rail': {'kind': 'account', 'accountId': 'acc_1'},
      };
      final futureResult = NavLocationPayload.fromJson(futureVersionJson);
      expect(futureResult.rail, equals(const RailTarget.workspace()));
      expect(futureResult.workspaceSection, equals(WorkspaceSection.overview));

      // Corrupt payload
      final corruptResult = NavLocationPayload.fromJson({'invalid': true});
      expect(corruptResult.rail, equals(const RailTarget.workspace()));
      expect(corruptResult.workspaceSection, equals(WorkspaceSection.overview));
    });
  });

  group('AppNavController', () {
    late ProviderContainer container;
    late AppNavController controller;
    const zentaoModule = ZentaoModule();

    setUp(() {
      container = ProviderContainer();
      controller = container.read(appNavProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('selectAccount seeds default section if none recorded', () {
      controller.selectAccount('acc_zentao', module: zentaoModule);

      final state = controller.state;
      expect(state.rail, equals(const RailTarget.account('acc_zentao')));
      expect(state.locations.containsKey('acc_zentao'), isTrue);
      expect(
        state.locations['acc_zentao']!.section,
        equals(const SectionId('zentao.tasks')),
      );
    });

    test(
      'selectSection keeps the scope for the same ScopeKind and resets it otherwise',
      () {
        controller.selectAccount('acc_zentao', module: zentaoModule);
        controller.selectScope('proj_1');
        expect(controller.state.currentLocation?.scopeId, equals('proj_1'));

        // 1. Switch to a section with a DIFFERENT ScopeKind (tasks: project -> bugs: product)
        controller.selectSection(
          const SectionId('zentao.bugs'),
          module: zentaoModule,
        );
        expect(
          controller.state.currentLocation?.section,
          equals(const SectionId('zentao.bugs')),
        );
        expect(controller.state.currentLocation?.scopeId, isNull);

        // Set scope for bugs
        controller.selectScope('prod_99');
        expect(controller.state.currentLocation?.scopeId, equals('prod_99'));

        // 2. Switch to a section with the SAME ScopeKind (e.g. project -> project via explicit kinds)
        controller.selectSection(
          const SectionId('custom.tasks2'),
          oldScopeKind: ScopeKind.product,
          newScopeKind: ScopeKind.product,
        );
        expect(controller.state.currentLocation?.scopeId, equals('prod_99'));

        // 3. Switch to a section with DIFFERENT explicit ScopeKind
        controller.selectSection(
          const SectionId('custom.repos'),
          oldScopeKind: ScopeKind.product,
          newScopeKind: ScopeKind.repository,
        );
        expect(controller.state.currentLocation?.scopeId, isNull);
      },
    );

    test('recentScopeIds is capped at 5, deduplicated, and newest first', () {
      controller.selectAccount('acc_zentao', module: zentaoModule);

      controller.selectScope('scope_1');
      controller.selectScope('scope_2');
      controller.selectScope('scope_3');
      controller.selectScope('scope_4');
      controller.selectScope('scope_5');

      expect(
        controller.state.currentLocation?.recentScopeIds,
        equals(['scope_5', 'scope_4', 'scope_3', 'scope_2', 'scope_1']),
      );

      // Adding 6th: should drop the oldest ('scope_1')
      controller.selectScope('scope_6');
      expect(
        controller.state.currentLocation?.recentScopeIds,
        equals(['scope_6', 'scope_5', 'scope_4', 'scope_3', 'scope_2']),
      );

      // Deduplication: selecting 'scope_4' moves it to index 0
      controller.selectScope('scope_4');
      expect(
        controller.state.currentLocation?.recentScopeIds,
        equals(['scope_4', 'scope_6', 'scope_5', 'scope_3', 'scope_2']),
      );
      expect(
        controller.state.currentLocation?.recentScopeIds.length,
        equals(5),
      );
    });

    test(
      'onWorkspaceChanged falls back to Overview when the account is gone, and restores location when present',
      () {
        controller.selectAccount('acc_1', module: zentaoModule);
        controller.selectScope('p_1');

        // Account acc_1 is still present in workspace
        controller.onWorkspaceChanged({'acc_1', 'acc_2'});
        expect(
          controller.state.rail,
          equals(const RailTarget.account('acc_1')),
        );
        expect(controller.state.currentLocation?.scopeId, equals('p_1'));

        // Account acc_1 is NOT present in new workspace
        controller.onWorkspaceChanged({'acc_2', 'acc_3'});
        expect(controller.state.rail, equals(const RailTarget.workspace()));
        expect(
          controller.state.workspaceSection,
          equals(WorkspaceSection.overview),
        );

        // But location for acc_1 is still preserved in state.locations for when user returns
        expect(controller.state.locations['acc_1']?.scopeId, equals('p_1'));
      },
    );

    test(
      'onAccountRemoved falls back to Overview and prunes account from locations',
      () {
        controller.selectAccount('acc_to_delete', module: zentaoModule);
        expect(
          controller.state.rail,
          equals(const RailTarget.account('acc_to_delete')),
        );

        controller.onAccountRemoved('acc_to_delete');
        expect(controller.state.rail, equals(const RailTarget.workspace()));
        expect(
          controller.state.workspaceSection,
          equals(WorkspaceSection.overview),
        );
        expect(
          controller.state.locations.containsKey('acc_to_delete'),
          isFalse,
        );
      },
    );

    test(
      'selectWorkspaceSection updates workspace section and marks user selection',
      () {
        controller.selectWorkspaceSection(WorkspaceSection.integrations);
        expect(controller.state.rail, equals(const RailTarget.workspace()));
        expect(
          controller.state.workspaceSection,
          equals(WorkspaceSection.integrations),
        );
        expect(controller.state.userSelectedWorkspace, isTrue);
      },
    );

    test(
      'selectDefaultAppIfApplicable selects first app and activates its first feature',
      () {
        final accounts = [
          const Account(
            id: 'gh_1',
            workspaceId: 'ws_1',
            providerType: ProviderType.github,
            handle: 'octocat',
          ),
          const Account(
            id: 'zt_1',
            workspaceId: 'ws_1',
            providerType: ProviderType.zentao,
            handle: 'zentao_user',
          ),
        ];
        final registry = {
          ProviderType.zentao: zentaoModule,
          ProviderType.github: const GithubModule(),
        };

        // Initially on workspace
        expect(controller.state.rail, equals(const RailTarget.workspace()));

        // ZenTao is sorted first, its default section is zentao.tasks
        controller.selectDefaultAppIfApplicable(
          accounts: accounts,
          registry: registry,
        );

        expect(controller.state.rail, equals(const RailTarget.account('zt_1')));
        expect(
          controller.state.locations['zt_1']?.section,
          equals(const SectionId('zentao.tasks')),
        );

        // Explicit workspace selection prevents auto-selection
        controller.selectWorkspaceSection(WorkspaceSection.overview);
        expect(controller.state.rail, equals(const RailTarget.workspace()));
        expect(controller.state.userSelectedWorkspace, isTrue);

        controller.selectDefaultAppIfApplicable(
          accounts: accounts,
          registry: registry,
        );
        expect(controller.state.rail, equals(const RailTarget.workspace()));

        // onWorkspaceSwitched resets userSelectedWorkspace and activates first app & feature
        final newAccounts = [
          const Account(
            id: 'gh_2',
            workspaceId: 'ws_2',
            providerType: ProviderType.github,
            handle: 'octo2',
          ),
        ];
        controller.onWorkspaceSwitched(
          newAccounts: newAccounts,
          registry: registry,
        );
        expect(controller.state.rail, equals(const RailTarget.account('gh_2')));
        expect(
          controller.state.locations['gh_2']?.section,
          equals(const SectionId('github.pulls')),
        );
        expect(controller.state.userSelectedWorkspace, isFalse);
      },
    );

    test('Account.sort orders ZenTao first, GitHub second, GitLab third', () {
      final accounts = [
        const Account(
          id: '3',
          workspaceId: 'w',
          providerType: ProviderType.gitlab,
          handle: 'gl',
        ),
        const Account(
          id: '1',
          workspaceId: 'w',
          providerType: ProviderType.github,
          handle: 'gh',
        ),
        const Account(
          id: '2',
          workspaceId: 'w',
          providerType: ProviderType.zentao,
          handle: 'zt',
        ),
      ];
      final sorted = Account.sort(accounts);
      expect(
        sorted.map((a) => a.providerType).toList(),
        equals([ProviderType.zentao, ProviderType.github, ProviderType.gitlab]),
      );
    });
  });

  group('SettingsNavLocationStore', () {
    late AppDatabase db;
    late SettingsNavLocationStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = SettingsNavLocationStore(db);
    });

    tearDown(() async {
      store.dispose();
      await db.close();
    });

    test('load returns null when no saved location exists', () async {
      final loaded = await store.load();
      expect(loaded, isNull);
    });

    test('save with flush persists and restores payload correctly', () async {
      const payload = NavLocationPayload(
        rail: RailTarget.account('acc_store_test'),
        workspaceSection: WorkspaceSection.members,
        locations: {
          'acc_store_test': ToolLocation(
            section: SectionId('zentao.tasks'),
            scopeId: 'scope_100',
            quickScope: QuickScope.reviewRequested,
            viewModes: {SectionId('zentao.tasks'): ViewModeId('list')},
            recentScopeIds: ['scope_100'],
          ),
        },
      );

      store.save(payload);
      await store.flush();

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.rail, equals(const RailTarget.account('acc_store_test')));
      expect(loaded.workspaceSection, equals(WorkspaceSection.members));
      final loc = loaded.locations['acc_store_test']!;
      expect(loc.section, equals(const SectionId('zentao.tasks')));
      expect(loc.scopeId, equals('scope_100'));
      expect(loc.quickScope, equals(QuickScope.reviewRequested));
      expect(
        loc.viewModes[const SectionId('zentao.tasks')],
        equals(const ViewModeId('list')),
      );
    });

    test('load recovers with default state on corrupt database row', () async {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS app_settings_kv (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      await db.customStatement('''
        INSERT INTO app_settings_kv (key, value, updated_at)
        VALUES ('nav.last_location.v1', '{corrupt json', 123456);
      ''');

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.rail, equals(const RailTarget.workspace()));
      expect(loaded.workspaceSection, equals(WorkspaceSection.overview));
      expect(loaded.locations, isEmpty);
    });
  });
}

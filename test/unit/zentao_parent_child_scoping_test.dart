import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/pinned_execution.dart';
import 'package:work_nexus/core/util/synthetic_labels.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_scope_providers.dart';
import 'package:work_nexus/tools/zentao/zentao_module.dart';

final _testTasksScopeProvider =
    Provider.family<List<Ticket>, List<Ticket>>(scopeZenTaoTasks);

final _testBugsScopeProvider =
    Provider.family<List<Ticket>, List<Ticket>>(scopeZenTaoBugs);

void main() {
  group('ZenTao Parent/Child Scoping', () {
    const accountId = 'zt1';
    const projectId = 'proj100';
    const otherProjectId = 'proj200';
    const execId1 = 'exec1';
    const execId2 = 'exec2';
    const otherExecId = 'execOther';

    Ticket makeTask({
      required String id,
      required String projectId,
      String? taskProject,
      String? execution,
      List<String> labels = const [],
    }) {
      return Ticket(
        id: id,
        accountId: accountId,
        projectId: projectId,
        providerType: ProviderType.zentao,
        externalKey: id,
        externalType: 'task',
        title: 'Task $id',
        body: '',
        priority: Priority.medium,
        status: UnifiedStatus.todo,
        providerStatus: 'wait',
        sourceHash: 'hash_$id',
        labels: labels,
        providerEntity: ZenTaoTaskEntity(
          project: taskProject ?? projectId,
          execution: execution,
        ),
      );
    }

    final taskInProjDirect = makeTask(
      id: 'task-1',
      projectId: projectId,
    );

    final taskInChildExec = makeTask(
      id: 'task-2',
      projectId: '$accountId:execution',
      taskProject: projectId,
      execution: execId1,
      labels: [zentaoExecutionLabel(execId1)],
    );

    final taskInOtherProj = makeTask(
      id: 'task-3',
      projectId: otherProjectId,
      taskProject: otherProjectId,
      execution: otherExecId,
      labels: [zentaoExecutionLabel(otherExecId)],
    );

    test(
      'scopeZenTaoTasks when clicking parent project filters all child tasks in that project',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final nav = container.read(appNavProvider.notifier);
        nav.selectAccount(accountId, module: const ZentaoModule());
        nav.selectScope(projectId);

        final allTasks = [taskInProjDirect, taskInChildExec, taskInOtherProj];
        final scoped = container.read(_testTasksScopeProvider(allTasks));

        expect(scoped.map((t) => t.id), containsAll(['task-1', 'task-2']));
        expect(scoped.map((t) => t.id), isNot(contains('task-3')));
      },
    );

    test(
      'scopeZenTaoTasks when selecting child execution filters strictly to that execution',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(selectedZenTaoExecutionProvider.notifier).select(
          const ProviderExecution(
            id: execId1,
            name: 'Sprint 1',
            projectId: projectId,
            accountId: accountId,
          ),
        );

        final allTasks = [taskInProjDirect, taskInChildExec, taskInOtherProj];
        final scoped = container.read(_testTasksScopeProvider(allTasks));

        expect(scoped.map((t) => t.id), [taskInChildExec.id]);
      },
    );

    test(
      'scopeZenTaoBugs when clicking parent product filters all bugs in that product',
      () {
        const prodId = 'prod1';
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(selectedZenTaoProductProvider.notifier).select(
          const ProviderProduct(
            id: prodId,
            name: 'Product 1',
            accountId: accountId,
          ),
        );

        Ticket makeBug({
          required String id,
          required String productId,
          String? execution,
          List<String> labels = const [],
        }) {
          return Ticket(
            id: id,
            accountId: accountId,
            projectId: '$accountId:Bug',
            providerType: ProviderType.zentao,
            externalKey: id,
            externalType: 'bug',
            title: 'Bug $id',
            body: '',
            priority: Priority.high,
            status: UnifiedStatus.todo,
            providerStatus: 'active',
            sourceHash: 'hash_$id',
            labels: labels,
            providerEntity: ZenTaoBugEntity(
              product: productId,
              execution: execution,
            ),
          );
        }

        final bug1InProd = makeBug(
          id: 'bug-1',
          productId: prodId,
          execution: execId1,
          labels: [zentaoProductLabel(prodId)],
        );

        final bug2InProdChildExec = makeBug(
          id: 'bug-2',
          productId: prodId,
          execution: execId2,
          labels: [zentaoExecutionLabel(execId2)],
        );

        final bugInOtherProd = makeBug(
          id: 'bug-3',
          productId: 'prod2',
          labels: [zentaoProductLabel('prod2')],
        );

        final scoped = container.read(
          _testBugsScopeProvider([bug1InProd, bug2InProdChildExec, bugInOtherProd]),
        );

        expect(scoped.map((t) => t.id), containsAll(['bug-1', 'bug-2']));
        expect(scoped.map((t) => t.id), isNot(contains('bug-3')));
      },
    );

    test(
      'scopeZenTaoBugs when selecting child execution filters strictly to that execution',
      () {
        const prodId = 'prod1';
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(selectedZenTaoProductProvider.notifier).select(
          const ProviderProduct(
            id: prodId,
            name: 'Product 1',
            accountId: accountId,
          ),
        );
        container.read(selectedZenTaoExecutionProvider.notifier).select(
          const ProviderExecution(
            id: execId1,
            name: 'Sprint 1',
            projectId: projectId,
            accountId: accountId,
          ),
        );

        Ticket makeBug({
          required String id,
          required String productId,
          String? execution,
          List<String> labels = const [],
        }) {
          return Ticket(
            id: id,
            accountId: accountId,
            projectId: '$accountId:Bug',
            providerType: ProviderType.zentao,
            externalKey: id,
            externalType: 'bug',
            title: 'Bug $id',
            body: '',
            priority: Priority.high,
            status: UnifiedStatus.todo,
            providerStatus: 'active',
            sourceHash: 'hash_$id',
            labels: labels,
            providerEntity: ZenTaoBugEntity(
              product: productId,
              execution: execution,
            ),
          );
        }

        final bug1InProd = makeBug(
          id: 'bug-1',
          productId: prodId,
          execution: execId1,
          labels: [zentaoProductLabel(prodId), zentaoExecutionLabel(execId1)],
        );

        final bug2InProdChildExec = makeBug(
          id: 'bug-2',
          productId: prodId,
          execution: execId2,
          labels: [zentaoProductLabel(prodId), zentaoExecutionLabel(execId2)],
        );

        final scoped = container.read(
          _testBugsScopeProvider([bug1InProd, bug2InProdChildExec]),
        );

        expect(scoped.map((t) => t.id), ['bug-1']);
      },
    );

    test(
      'pinning child execution shows parent in pinned section with isPinned false, unpinning removes it',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final settings = container.read(appSettingsProvider.notifier);
        const execution = PinnedExecution(
          accountId: accountId,
          projectId: projectId,
          executionId: execId1,
          name: 'Sprint 1',
        );

        settings.togglePinnedExecution(execution);

        final state = container.read(appSettingsProvider);
        expect(state.pinnedExecutions, contains(execution));
        // Parent project is NOT pinned
        expect(state.pinnedProjects, isNot(contains('$accountId:$projectId')));

        // Simulate pinned list calculation in scope list:
        final pinnedKeys = state.pinnedProjects;
        final pinnedExecs = state.pinnedExecutions;
        final hasPinnedChild = pinnedExecs.any((e) => e.projectId == projectId);
        final isProjPinned = pinnedKeys.contains('$accountId:$projectId');

        // Parent project is included in pinned list
        expect(isProjPinned || hasPinnedChild, isTrue);
        // But parent pin status is false (not pinned)
        expect(isProjPinned, isFalse);

        // Unpinning the child removes it and parent disappears
        settings.togglePinnedExecution(execution);
        final stateAfter = container.read(appSettingsProvider);
        final hasChildAfter =
            stateAfter.pinnedExecutions.any((e) => e.projectId == projectId);
        final isProjPinnedAfter =
            stateAfter.pinnedProjects.contains('$accountId:$projectId');
        expect(isProjPinnedAfter || hasChildAfter, isFalse);
      },
    );

    test(
      'pinning parent project has isPinned true and does not pin child executions',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final settings = container.read(appSettingsProvider.notifier);
        settings.togglePinnedProject('$accountId:$projectId');

        final state = container.read(appSettingsProvider);
        // Parent is pinned
        expect(state.pinnedProjects, contains('$accountId:$projectId'));
        // Children are NOT pinned
        expect(state.pinnedExecutions, isEmpty);

        final isProjPinned =
            state.pinnedProjects.contains('$accountId:$projectId');
        expect(isProjPinned, isTrue);
      },
    );
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/util/synthetic_labels.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_scope_providers.dart';

void main() {
  group('ZenTao Parent vs Child Execution Scoping', () {
    const accountId = 'zt1';
    const productId = 'prod_10';
    const productName = 'VN_IM_Chat';

    final bug1Exec1 = Ticket(
      id: 'zt1:bug:1',
      externalKey: '1',
      externalType: 'bug',
      accountId: accountId,
      projectId: '$accountId:$productName',
      providerType: ProviderType.zentao,
      title: 'Bug in sprint 1',
      body: 'Details for bug 1',
      status: UnifiedStatus.todo,
      providerStatus: 'active',
      sourceHash: 'h1',
      priority: Priority.high,
      labels: [zentaoProductLabel(productId), zentaoExecutionLabel('exec_1')],
      providerEntity: const TicketProviderEntity.zentaoBug(
        product: productId,
        productName: productName,
        execution: 'exec_1',
        executionName: 'Sprint 1',
      ),
    );

    final bug2Exec2 = Ticket(
      id: 'zt1:bug:2',
      externalKey: '2',
      externalType: 'bug',
      accountId: accountId,
      projectId: '$accountId:$productName',
      providerType: ProviderType.zentao,
      title: 'Bug in sprint 2',
      body: 'Details for bug 2',
      status: UnifiedStatus.todo,
      providerStatus: 'active',
      sourceHash: 'h2',
      priority: Priority.medium,
      labels: [zentaoProductLabel(productId), zentaoExecutionLabel('exec_2')],
      providerEntity: const TicketProviderEntity.zentaoBug(
        product: productId,
        productName: productName,
        execution: 'exec_2',
        executionName: 'Sprint 2',
      ),
    );

    final bug3NoExec = Ticket(
      id: 'zt1:bug:3',
      externalKey: '3',
      externalType: 'bug',
      accountId: accountId,
      projectId: '$accountId:$productName',
      providerType: ProviderType.zentao,
      title: 'Bug with no sprint',
      body: 'Details for bug 3',
      status: UnifiedStatus.todo,
      providerStatus: 'active',
      sourceHash: 'h3',
      priority: Priority.low,
      labels: [zentaoProductLabel(productId)],
      providerEntity: const TicketProviderEntity.zentaoBug(
        product: productId,
        productName: productName,
      ),
    );

    final List<Ticket> allBugs = [bug1Exec1, bug2Exec2, bug3NoExec];

    test(
      'parent product selected with no execution loads all bugs for that product',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Select parent product
        container
            .read(selectedZenTaoProductProvider.notifier)
            .select(
              const ProviderProduct(
                id: productId,
                name: productName,
                accountId: accountId,
              ),
            );
        container.read(selectedZenTaoExecutionProvider.notifier).clear();

        final scoped = container.read(
          Provider((ref) => scopeZenTaoBugs(ref, allBugs)),
        );

        // All 3 bugs belong to the parent product
        expect(scoped.length, 3);
        expect(
          scoped.map((t) => t.id),
          containsAll(['zt1:bug:1', 'zt1:bug:2', 'zt1:bug:3']),
        );
      },
    );

    test(
      'child execution selected filters bugs exclusively to that execution',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Select parent product
        container
            .read(selectedZenTaoProductProvider.notifier)
            .select(
              const ProviderProduct(
                id: productId,
                name: productName,
                accountId: accountId,
              ),
            );

        // Select child execution: exec_1
        container
            .read(selectedZenTaoExecutionProvider.notifier)
            .select(
              const ProviderExecution(
                id: 'exec_1',
                name: 'Sprint 1',
                projectId: 'proj_10',
                accountId: accountId,
              ),
            );

        final scoped = container.read(
          Provider((ref) => scopeZenTaoBugs(ref, allBugs)),
        );

        // Only bug1 belongs to exec_1
        expect(scoped.length, 1);
        expect(scoped.first.id, 'zt1:bug:1');
      },
    );

    test(
      'parent project scope in tasks loads all tasks across executions for that project',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final task1 = Ticket(
          id: 'zt1:task:1',
          externalKey: '101',
          accountId: accountId,
          projectId: 'proj_10',
          providerType: ProviderType.zentao,
          externalType: 'task',
          title: 'Task in sprint 1',
          body: 'Task 1 description',
          status: UnifiedStatus.inprogress,
          providerStatus: 'doing',
          sourceHash: 'ht1',
          priority: Priority.high,
          labels: [zentaoExecutionLabel('exec_1')],
          providerEntity: const TicketProviderEntity.zentaoTask(
            project: 'proj_10',
            execution: 'exec_1',
          ),
        );

        final task2 = Ticket(
          id: 'zt1:task:2',
          externalKey: '102',
          accountId: accountId,
          projectId: 'proj_10',
          providerType: ProviderType.zentao,
          externalType: 'task',
          title: 'Task in sprint 2',
          body: 'Task 2 description',
          status: UnifiedStatus.todo,
          providerStatus: 'wait',
          sourceHash: 'ht2',
          priority: Priority.medium,
          labels: [zentaoExecutionLabel('exec_2')],
          providerEntity: const TicketProviderEntity.zentaoTask(
            project: 'proj_10',
            execution: 'exec_2',
          ),
        );

        final List<Ticket> tasks = [task1, task2];

        // Select parent project scope
        container.read(appNavProvider.notifier).selectAccount(accountId);
        container.read(appNavProvider.notifier).selectScope('proj_10');
        container.read(selectedZenTaoExecutionProvider.notifier).clear();

        final scoped = container.read(
          Provider((ref) => scopeZenTaoTasks(ref, tasks)),
        );

        // All tasks belonging to proj_10 are loaded
        expect(scoped.length, 2);
      },
    );
  });
}

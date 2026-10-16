import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/pinned_execution.dart';

void main() {
  group('AppSettings Pin Hierarchy', () {
    test('pinning a child execution also pins its parent project', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appSettingsProvider.notifier);
      const execution = PinnedExecution(
        accountId: 'acc1',
        projectId: 'proj1',
        executionId: 'exec1',
        name: 'Sprint 1',
      );

      controller.togglePinnedExecution(execution);

      final settings = container.read(appSettingsProvider);
      expect(settings.pinnedExecutions, contains(execution));
      expect(
        settings.pinnedProjects,
        contains(zentaoProjectPinKey('acc1', 'proj1')),
      );
    });

    test('unpinning an execution keeps the parent project pinned', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appSettingsProvider.notifier);
      const execution = PinnedExecution(
        accountId: 'acc1',
        projectId: 'proj1',
        executionId: 'exec1',
        name: 'Sprint 1',
      );

      controller.togglePinnedExecution(execution);
      controller.togglePinnedExecution(execution); // toggle off

      final settings = container.read(appSettingsProvider);
      expect(settings.pinnedExecutions, isEmpty);
      expect(
        settings.pinnedProjects,
        contains(zentaoProjectPinKey('acc1', 'proj1')),
      );
    });

    test('unpinning a project also unpins all its child executions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appSettingsProvider.notifier);
      const execution1 = PinnedExecution(
        accountId: 'acc1',
        projectId: 'proj1',
        executionId: 'exec1',
        name: 'Sprint 1',
      );
      const execution2 = PinnedExecution(
        accountId: 'acc1',
        projectId: 'proj1',
        executionId: 'exec2',
        name: 'Sprint 2',
      );
      const otherExecution = PinnedExecution(
        accountId: 'acc1',
        projectId: 'proj2',
        executionId: 'exec3',
        name: 'Other Sprint',
      );

      controller.togglePinnedExecution(execution1);
      controller.togglePinnedExecution(execution2);
      controller.togglePinnedExecution(otherExecution);

      expect(container.read(appSettingsProvider).pinnedExecutions.length, 3);
      expect(
        container.read(appSettingsProvider).pinnedProjects,
        contains(zentaoProjectPinKey('acc1', 'proj1')),
      );

      // Unpin proj1
      controller.togglePinnedProject(zentaoProjectPinKey('acc1', 'proj1'));

      final settings = container.read(appSettingsProvider);
      expect(
        settings.pinnedProjects,
        isNot(contains(zentaoProjectPinKey('acc1', 'proj1'))),
      );
      expect(
        settings.pinnedProjects,
        contains(zentaoProjectPinKey('acc1', 'proj2')),
      );
      expect(settings.pinnedExecutions, [otherExecution]);
    });

    test('pinning a project with childExecutions pins all of them', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appSettingsProvider.notifier);
      const execs = [
        PinnedExecution(
          accountId: 'acc1',
          projectId: 'proj1',
          executionId: 'exec1',
          name: 'Sprint 1',
        ),
        PinnedExecution(
          accountId: 'acc1',
          projectId: 'proj1',
          executionId: 'exec2',
          name: 'Sprint 2',
        ),
      ];

      controller.togglePinnedProject(
        zentaoProjectPinKey('acc1', 'proj1'),
        childExecutions: execs,
      );

      final settings = container.read(appSettingsProvider);
      expect(
        settings.pinnedProjects,
        contains(zentaoProjectPinKey('acc1', 'proj1')),
      );
      expect(settings.pinnedExecutions.map((e) => e.key), [
        'acc1:exec1',
        'acc1:exec2',
      ]);
    });
    // Products (bare `accountId:id`, the first pin format) and projects are
    // numbered apart by ZenTao: the same id must not tie them together.
    test('a product and a project with the same id stay apart', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(appSettingsProvider.notifier);
      const projectExec = PinnedExecution(
        accountId: 'acc1',
        projectId: '30',
        executionId: 'e1',
        name: 'Sprint 1',
      );
      controller
        ..togglePinnedExecution(projectExec)
        ..togglePinnedProject('acc1:30')
        ..togglePinnedProject('acc1:30');

      final settings = container.read(appSettingsProvider);
      expect(settings.pinnedExecutions, [projectExec]);
      expect(settings.pinnedProjects, {zentaoProjectPinKey('acc1', '30')});
    });

    test('unpinning a product drops the executions pinned with it, only', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(appSettingsProvider.notifier);
      const ownExec = PinnedExecution(
        accountId: 'acc1',
        projectId: '12',
        executionId: 'e9',
        name: 'Other',
      );
      controller
        ..togglePinnedExecution(ownExec)
        ..togglePinnedProject(
          'acc1:12',
          childExecutions: const [
            PinnedExecution(
              accountId: 'acc1',
              projectId: '30',
              executionId: 'e1',
              name: 'Sprint 1',
            ),
          ],
        );
      expect(
        container.read(appSettingsProvider).pinnedExecutions,
        hasLength(2),
      );

      controller.togglePinnedProject('acc1:12');

      expect(container.read(appSettingsProvider).pinnedExecutions, [ownExec]);
    });
  });
}

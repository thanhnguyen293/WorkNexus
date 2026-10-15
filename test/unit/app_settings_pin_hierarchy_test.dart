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
      expect(settings.pinnedProjects, contains('acc1:proj1'));
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
      expect(settings.pinnedProjects, contains('acc1:proj1'));
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
        contains('acc1:proj1'),
      );

      // Unpin proj1
      controller.togglePinnedProject('acc1:proj1');

      final settings = container.read(appSettingsProvider);
      expect(settings.pinnedProjects, isNot(contains('acc1:proj1')));
      expect(settings.pinnedProjects, contains('acc1:proj2'));
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

      controller.togglePinnedProject('acc1:proj1', childExecutions: execs);

      final settings = container.read(appSettingsProvider);
      expect(settings.pinnedProjects, contains('acc1:proj1'));
      expect(settings.pinnedExecutions, containsAll(execs));
    });
  });
}

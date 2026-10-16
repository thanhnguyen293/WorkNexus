import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/pinned_execution.dart';

void main() {
  group('AppSettings Pin Hierarchy', () {
    test('pinning a child execution does NOT pin its parent project', () {
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
      expect(settings.pinnedProjects, isNot(contains('acc1:proj1')));
    });

    test('unpinning an execution leaves pinnedProjects untouched', () {
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
      expect(settings.pinnedProjects, isEmpty);
    });

    test('pinning and unpinning a project does NOT modify child executions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appSettingsProvider.notifier);
      const execution = PinnedExecution(
        accountId: 'acc1',
        projectId: 'proj1',
        executionId: 'exec1',
        name: 'Sprint 1',
      );

      // Pin child execution first
      controller.togglePinnedExecution(execution);
      expect(container.read(appSettingsProvider).pinnedExecutions, [execution]);
      expect(container.read(appSettingsProvider).pinnedProjects, isEmpty);

      // Pin parent project
      controller.togglePinnedProject('acc1:proj1');
      expect(
        container.read(appSettingsProvider).pinnedProjects,
        contains('acc1:proj1'),
      );
      expect(container.read(appSettingsProvider).pinnedExecutions, [execution]);

      // Unpin parent project
      controller.togglePinnedProject('acc1:proj1');
      expect(
        container.read(appSettingsProvider).pinnedProjects,
        isNot(contains('acc1:proj1')),
      );
      // Independent child execution remains pinned
      expect(container.read(appSettingsProvider).pinnedExecutions, [execution]);
    });

    test('pinning a project does not add children to pinnedExecutions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appSettingsProvider.notifier);
      controller.togglePinnedProject('acc1:proj1');

      final settings = container.read(appSettingsProvider);
      expect(settings.pinnedProjects, contains('acc1:proj1'));
      expect(settings.pinnedExecutions, isEmpty);
    });
  });
}

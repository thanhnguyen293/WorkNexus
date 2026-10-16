import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/pinned_execution.dart';

const _exec = PinnedExecution(
  accountId: 'acc1',
  projectId: 'proj1',
  executionId: 'exec1',
  name: 'Sprint 1',
);

void main() {
  late ProviderContainer container;
  late AppSettingsController controller;

  setUp(() {
    container = ProviderContainer();
    controller = container.read(appSettingsProvider.notifier);
  });

  tearDown(() => container.dispose());

  // ZenTao projects only hold executions: pins are executions, and no
  // project is pinned along with one.
  test('pinning an execution pins it alone', () {
    controller.togglePinnedExecution(_exec);

    final settings = container.read(appSettingsProvider);
    expect(settings.pinnedExecutions, [_exec]);
    expect(settings.pinnedProjects, isEmpty);
  });

  test('a second toggle unpins it, whatever its name now is', () {
    controller
      ..togglePinnedExecution(_exec)
      ..togglePinnedExecution(
        const PinnedExecution(
          accountId: 'acc1',
          projectId: 'proj1',
          executionId: 'exec1',
          name: 'Renamed',
        ),
      );

    expect(container.read(appSettingsProvider).pinnedExecutions, isEmpty);
  });

  test('a product or repo pin leaves the executions alone', () {
    controller
      ..togglePinnedExecution(_exec)
      ..togglePinnedProject('acc1:proj1')
      ..togglePinnedProject('acc1:proj1');

    final settings = container.read(appSettingsProvider);
    expect(settings.pinnedExecutions, [_exec]);
    expect(settings.pinnedProjects, isEmpty);
  });
}

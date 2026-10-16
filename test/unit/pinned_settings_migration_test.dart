import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/data/mappers/mappers.dart';
import 'package:work_nexus/core/database/database.dart' show decodeLabels;
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/pinned_execution.dart';

/// Pins as older versions saved them: products as bare `accountId:id` keys,
/// executions without the pin they came with.
const _oldProjectsJson = '["zt:12","gl-a:77"]';
const _oldExecutionsJson =
    '[{"accountId":"zt","projectId":"30","executionId":"e1","name":"S1"}]';

void main() {
  test('pins saved by older versions load as they were', () {
    final projects = decodeLabels(_oldProjectsJson).toSet();
    final executions = decodePinnedExecutions(_oldExecutionsJson);

    expect(projects, {'zt:12', 'gl-a:77'});
    expect(executions.single.key, 'zt:e1');
    expect(executions.single.parentKey, isNull);
    // It goes with its project, as it did.
    expect(executions.single.ownerKey, zentaoProjectPinKey('zt', '30'));
    // Saved again, it reads back the same.
    expect(
      decodePinnedExecutions(encodePinnedExecutions(executions)),
      executions,
    );
  });

  test('old pins keep their cascades in the separated key spaces', () {
    final container = ProviderContainer(
      overrides: [
        initialAppSettingsProvider.overrideWithValue(
          AppSettings(
            pinnedProjects: decodeLabels(_oldProjectsJson).toSet(),
            pinnedExecutions: decodePinnedExecutions(_oldExecutionsJson),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(appSettingsProvider.notifier);

    // The old product pin 'zt:12' is a product: unpinning it leaves the
    // execution of project 30 alone.
    controller.togglePinnedProject('zt:12');
    expect(container.read(appSettingsProvider).pinnedExecutions, hasLength(1));

    // Its project's unpin takes it along.
    controller
      ..togglePinnedProject(zentaoProjectPinKey('zt', '30'))
      ..togglePinnedProject(zentaoProjectPinKey('zt', '30'));
    expect(container.read(appSettingsProvider).pinnedExecutions, isEmpty);
    expect(container.read(appSettingsProvider).pinnedProjects, {'gl-a:77'});
  });
}

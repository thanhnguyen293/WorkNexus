import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';

Workspace _ws(String id, [String? name]) =>
    Workspace(id: id, name: name ?? id, shortCode: 'W', colorValue: 0);

void main() {
  late StreamController<List<Workspace>> workspaces;
  late ProviderContainer container;

  Future<void> emit(List<Workspace> list) async {
    workspaces.add(list);
    await container.read(workspacesProvider.future);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    workspaces = StreamController<List<Workspace>>();
    container = ProviderContainer(
      overrides: [workspacesProvider.overrideWith((ref) => workspaces.stream)],
    );
    // Keep the derived providers alive so they see every emission.
    container.listen(activeWorkspaceProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await workspaces.close();
  });

  test('defaults to the first workspace', () async {
    await emit([_ws('a'), _ws('b')]);

    expect(container.read(activeWorkspaceProvider)?.id, 'a');
  });

  test('keeps the joined workspace when the list changes', () async {
    await emit([_ws('a'), _ws('b')]);
    container.read(activeWorkspaceIdProvider.notifier).state = 'b';

    await emit([_ws('a', 'renamed'), _ws('b'), _ws('c')]);

    expect(container.read(activeWorkspaceIdProvider), 'b');
    expect(container.read(activeWorkspaceProvider)?.id, 'b');
  });

  test(
    'falls back to the first workspace once the joined one is gone',
    () async {
      await emit([_ws('a'), _ws('b')]);
      container.read(activeWorkspaceIdProvider.notifier).state = 'b';

      await emit([_ws('a')]);

      expect(container.read(activeWorkspaceProvider)?.id, 'a');
    },
  );
}

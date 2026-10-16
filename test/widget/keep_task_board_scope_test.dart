import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/pinned_execution.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/util/keep_task_board_scope.dart';

const _account = Account(
  id: 'zt',
  workspaceId: 'w',
  providerType: ProviderType.zentao,
  handle: 'me',
);

const _projects = [
  ProviderProject(id: '1', name: 'First', accountId: 'zt'),
  ProviderProject(id: '2', name: 'Pinned', accountId: 'zt'),
];

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    String? scope,
  }) async {
    final container = ProviderContainer(
      overrides: [
        zentaoProjectsProvider(
          'zt',
        ).overrideWith((ref) => Stream.value(_projects)),
        initialAppSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    container.read(appNavProvider.notifier)
      ..selectAccount('zt')
      ..selectSection(const SectionId('zentao.tasks'))
      ..selectScope(scope);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final location = ref.watch(currentToolLocationProvider);
            if (location != null) {
              keepTaskBoardScope(context, ref, _account, location);
            }
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  String? scope(ProviderContainer c) =>
      c.read(currentToolLocationProvider)?.scopeId;

  testWidgets('with nothing picked, a pinned execution opens (paged)', (
    tester,
  ) async {
    final container = await pump(
      tester,
      settings: const AppSettings(
        pinnedExecutions: [
          PinnedExecution(
            accountId: 'zt',
            projectId: '1',
            executionId: '50',
            name: 'Sprint 50',
          ),
        ],
      ),
    );

    expect(scope(container), '50');
    expect(container.read(selectedZenTaoExecutionProvider)?.executionId, '50');
  });

  testWidgets('else a pinned project', (tester) async {
    final container = await pump(
      tester,
      settings: AppSettings(pinnedProjects: {zentaoProjectPinKey('zt', '2')}),
    );

    expect(scope(container), '2');
    expect(container.read(selectedZenTaoExecutionProvider), isNull);
  });

  testWidgets('else the first project', (tester) async {
    final container = await pump(tester);

    expect(scope(container), '1');
  });

  testWidgets('a project still there is left as picked', (tester) async {
    final container = await pump(tester, scope: '2');

    expect(scope(container), '2');
  });

  testWidgets('a project that is gone gives way to another', (tester) async {
    final container = await pump(tester, scope: '99');

    expect(scope(container), '1');
  });
}

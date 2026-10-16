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
  ProviderProject(id: '2', name: 'Second', accountId: 'zt'),
];

const _pinned = PinnedExecution(
  accountId: 'zt',
  projectId: '2',
  executionId: '50',
  name: 'Sprint 50',
);

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    String? scope,
    List<ProviderExecution> firstProjectExecutions = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        zentaoProjectsProvider(
          'zt',
        ).overrideWith((ref) => Stream.value(_projects)),
        zentaoExecutionsProvider((
          accountId: 'zt',
          projectId: '1',
        )).overrideWith((ref) async => firstProjectExecutions),
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
  String? execution(ProviderContainer c) =>
      c.read(selectedZenTaoExecutionProvider)?.executionId;

  testWidgets('with nothing picked, a pinned execution opens', (tester) async {
    final c = await pump(
      tester,
      settings: const AppSettings(pinnedExecutions: [_pinned]),
    );

    expect((scope(c), execution(c)), ('50', '50'));
  });

  testWidgets('else the first execution of the first project', (tester) async {
    final c = await pump(
      tester,
      firstProjectExecutions: const [
        ProviderExecution(id: '7', name: 'S7', projectId: '1', accountId: 'zt'),
        ProviderExecution(id: '8', name: 'S8', projectId: '1', accountId: 'zt'),
      ],
    );

    expect((scope(c), execution(c)), ('7', '7'));
  });

  testWidgets('with no execution to pick, nothing is selected (never a '
      'project)', (tester) async {
    final c = await pump(tester);

    expect(scope(c), isNull);
    expect(execution(c), isNull);
  });

  testWidgets('a project-only scope gives way to an execution', (tester) async {
    final c = await pump(
      tester,
      scope: '2',
      settings: const AppSettings(pinnedExecutions: [_pinned]),
    );

    expect((scope(c), execution(c)), ('50', '50'));
  });

  testWidgets('a picked execution stays', (tester) async {
    final c = await pump(
      tester,
      settings: const AppSettings(pinnedExecutions: [_pinned]),
    );
    c.read(appNavProvider.notifier).selectScope('9');
    c
        .read(selectedZenTaoExecutionProvider.notifier)
        .select(
          const ProviderExecution(
            id: '9',
            name: 'S9',
            projectId: '1',
            accountId: 'zt',
          ),
        );
    await tester.pumpAndSettle();

    expect((scope(c), execution(c)), ('9', '9'));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/app/di/service_locator.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/project.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/tools/tool_module.dart';
import 'package:work_nexus/core/tools/tool_registry_provider.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/detail/presentation/detail_panel.dart';
import 'package:work_nexus/shared/sync/data/sync_service.dart';

class _MockSyncService extends Mock implements SyncService {}

class _FakeCustomToolModule extends ToolModule {
  const _FakeCustomToolModule();

  @override
  ProviderType get providerType => ProviderType.github;

  @override
  Widget? buildDetail(
    BuildContext context,
    Ticket ticket, {
    VoidCallback? onClose,
  }) {
    return const Center(child: Text('Fake Custom Tool Detail Body'));
  }

  @override
  Widget? buildActions(BuildContext context, Ticket ticket) => null;
}

const _testTicket = Ticket(
  id: 'fake:1',
  accountId: 'fake-acc',
  projectId: 'fake-proj',
  providerType: ProviderType.github,
  externalKey: '1',
  externalType: 'item',
  title: 'Test Ticket for S3 Spec',
  body: 'Body',
  priority: Priority.high,
  status: UnifiedStatus.todo,
  providerStatus: 'open',
  sourceHash: 'hash',
);

const _testAccount = Account(
  id: 'fake-acc',
  workspaceId: 'ws-1',
  providerType: ProviderType.github,
  handle: 'fake-user',
);

const _testWorkspace = Workspace(
  id: 'ws-1',
  name: 'Test Workspace',
  shortCode: 'WS',
  colorValue: 0xFF4A90E2,
);

void main() {
  late _MockSyncService sync;

  setUpAll(() {
    registerFallbackValue(_testTicket);
  });

  setUp(() async {
    sync = _MockSyncService();
    await getIt.reset();
    getIt.registerSingleton<SyncService>(sync);
    when(
      () => sync.syncTicketDetail(any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  tearDown(getIt.reset);

  testWidgets(
    'S3: a fake ToolModule registered in a test renders through shared/detail',
    (tester) async {
      final fakeRegistry = <ProviderType, ToolModule>{
        ProviderType.github: const _FakeCustomToolModule(),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            toolRegistryProvider.overrideWithValue(fakeRegistry),
            ticketsProvider.overrideWith((ref) => Stream.value([_testTicket])),
            lookupsProvider.overrideWith(
              (ref) => (
                accounts: {'fake-acc': _testAccount},
                workspaces: {'ws-1': _testWorkspace},
                projects: const <String, Project>{},
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            theme: buildAppTheme(
              variant: AppThemeVariant.light,
              surface: SurfaceStyle.outline,
              density: AppDensity.comfortable,
            ),
            home: const Scaffold(body: DetailPanel(ticketId: 'fake:1')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fake Custom Tool Detail Body'), findsOneWidget);
    },
  );
}

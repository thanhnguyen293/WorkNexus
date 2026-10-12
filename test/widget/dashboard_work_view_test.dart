import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:work_nexus/features/dashboard/domain/value_objects/dashboard_item_kind.dart';
import 'package:work_nexus/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:work_nexus/features/dashboard/presentation/widgets/dashboard_work_header.dart';
import 'package:work_nexus/features/dashboard/presentation/widgets/dashboard_work_view.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockRepository extends Mock implements DashboardRepository {}

const _account = Account(
  id: 'zt',
  workspaceId: 'w',
  providerType: ProviderType.zentao,
  handle: 'thanh',
);

Ticket _ticket(String id, String type, String title) => Ticket(
  id: 'zt:${type.toLowerCase()}:$id',
  accountId: 'zt',
  projectId: 'zt:p',
  providerType: ProviderType.zentao,
  externalKey: id,
  externalType: type,
  title: title,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: '',
  assignee: 'thanh',
);

void main() {
  Future<void> pump(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MockRepository();
    when(
      () => repository.syncAssignedWork(any()),
    ).thenAnswer((_) async => const Ok(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(repository),
          ticketsProvider.overrideWith(
            (ref) => Stream.value([
              _ticket('1', 'Task', 'Wire up push'),
              _ticket('2', 'Bug', 'Push opens nothing'),
            ]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [
                DashboardWorkHeader(
                  account: _account,
                  kind: DashboardItemKind.bug,
                ),
                Expanded(
                  child: DashboardWorkView(
                    account: _account,
                    kind: DashboardItemKind.bug,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a wide window shows tasks and bugs side by side', (
    tester,
  ) async {
    await pump(tester, width: 1400);

    expect(find.text('My work'), findsOneWidget);
    expect(find.text('Wire up push'), findsOneWidget);
    expect(find.text('Push opens nothing'), findsOneWidget);
    // Both lists show at once, so there is no tasks / bugs switch.
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Bugs'), findsOneWidget);
    final tasks = tester.getRect(find.text('Wire up push'));
    final bugs = tester.getRect(find.text('Push opens nothing'));
    expect(bugs.left, greaterThan(tasks.right));
  });

  testWidgets('a narrow window shows one list, picked in the header', (
    tester,
  ) async {
    await pump(tester, width: 700);

    expect(find.text('Push opens nothing'), findsOneWidget);
    expect(find.text('Wire up push'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Tasks',
        description: 'the tasks tab',
      ),
      findsOneWidget,
    );
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_row_copy_actions.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_task_row.dart';

void main() {
  const testTicket = Ticket(
    id: 'zt:task:5180',
    accountId: 'acc-1',
    projectId: 'proj-1',
    providerType: ProviderType.zentao,
    externalKey: '5180',
    title: '[Workspace] Build workspace switcher',
    body: 'Task body',
    priority: Priority.urgent,
    status: UnifiedStatus.inprogress,
    providerStatus: 'doing',
    sourceHash: 'hash-1',
    assignee: 'Son Vu',
    providerEntity: ZenTaoTaskEntity(
      taskType: 'devel',
      execution: '14',
      executionName: 'S-14',
      deadline: '2026-10-24',
    ),
  );

  Widget buildTestWidget({required Ticket ticket, String? openTicketId}) {
    return ProviderScope(
      overrides: [openTicketIdProvider.overrideWith((ref) => openTicketId)],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ZenTaoTaskRow(ticket: ticket),
          ),
        ),
      ),
    );
  }

  testWidgets('ZenTaoTaskRow renders all metadata without table grid lines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget(ticket: testTicket));
    await tester.pumpAndSettle();

    // ID
    expect(find.text('#5180'), findsOneWidget);

    // Module tag extracted from "[Workspace]"
    expect(find.text('[Workspace]'), findsOneWidget);

    // Clean title without bracket prefix
    expect(find.text('Build workspace switcher'), findsOneWidget);

    // Sprint execution tag
    expect(find.text('S-14'), findsOneWidget);

    // Status pill
    expect(find.text('In Progress'), findsOneWidget);

    // Assignee initials and name
    expect(find.text('SV'), findsOneWidget);
    expect(find.text('Son Vu'), findsOneWidget);
  });

  testWidgets('ZenTaoTaskRow handles unassigned task without sprint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const bareTicket = Ticket(
      id: 'zt:task:5181',
      accountId: 'acc-1',
      projectId: 'proj-1',
      providerType: ProviderType.zentao,
      externalKey: '5181',
      title: 'Simple task without module',
      body: '',
      priority: Priority.medium,
      status: UnifiedStatus.todo,
      providerStatus: 'wait',
      sourceHash: 'hash-2',
    );

    await tester.pumpWidget(buildTestWidget(ticket: bareTicket));
    await tester.pumpAndSettle();

    expect(find.text('#5181'), findsOneWidget);
    expect(find.text('Simple task without module'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);
  });

  testWidgets(
    'right click on ZenTaoTaskRow opens context menu with copy actions',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(ticket: testTicket));
      await tester.pumpAndSettle();

      // Right-click on the row
      await tester.tap(find.text('#5180'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Copy title'), findsOneWidget);
      expect(find.text('Copy ID (#5180)'), findsOneWidget);
      expect(find.text('Copy Markdown link'), findsOneWidget);
    },
  );

  testWidgets('hovering over ZenTaoTaskRow reveals quick copy button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget(ticket: testTicket));
    await tester.pumpAndSettle();

    expect(find.byType(ZenTaoRowQuickCopyButton), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(tester.getCenter(find.text('#5180')));
    await tester.pumpAndSettle();

    expect(find.byType(ZenTaoRowQuickCopyButton), findsOneWidget);
  });
}

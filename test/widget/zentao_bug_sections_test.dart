import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/adapters/zentao_ticket_editor.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/entities/zentao_ticket_form.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/open_zentao_execution.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/bug_detail_sections.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/zentao_linked_ticket.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockEditor extends Mock implements ZenTaoTicketEditor {}

Ticket _ticket(ZenTaoBugEntity bug) => Ticket(
  id: 'zt:bug:1',
  accountId: 'zt',
  projectId: 'zt:P',
  providerType: ProviderType.zentao,
  externalKey: '1',
  title: 't',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
  providerEntity: bug,
);

void main() {
  late _MockEditor editor;

  setUp(() {
    editor = _MockEditor();
    when(
      () => editor.bugOptions(any(), productId: any(named: 'productId')),
    ).thenAnswer((_) async => const Ok(BugFormOptions()));
  });

  Future<void> pump(
    WidgetTester tester,
    ZenTaoBugEntity bug, {
    OpenZenTaoExecution? openExecution,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          zenTaoTicketEditorProvider.overrideWithValue(editor),
          openZenTaoExecutionProvider.overrideWithValue(openExecution),
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
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZenTaoBugSections(bug, ticket: _ticket(bug)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, String label) =>
      tester.getTopLeft(find.text(label)).dy;

  testWidgets('classification reads triage first, then where, then links', (
    tester,
  ) async {
    await pump(
      tester,
      const ZenTaoBugEntity(
        severity: 2,
        product: '4',
        productName: 'VN_Socialfi',
        execution: '91',
        executionName: 'Sprint 12',
        task: '11548',
        taskName: 'Share button',
      ),
    );
    expect(top(tester, 'Severity'), lessThan(top(tester, 'Product')));
    expect(top(tester, 'Product'), lessThan(top(tester, 'Execution')));
    expect(top(tester, 'Task'), greaterThan(top(tester, 'Execution')));
  });

  testWidgets('product and execution show their names, not their ids', (
    tester,
  ) async {
    await pump(
      tester,
      const ZenTaoBugEntity(
        product: '4',
        productName: 'VN_Socialfi',
        execution: '91',
        executionName: 'Sprint 12',
      ),
    );
    expect(find.text('VN_Socialfi'), findsOneWidget);
    expect(find.text('VN_Socialfi · 4'), findsNothing);
    expect(find.text('Sprint 12'), findsOneWidget);
    expect(find.text('Sprint 12 · 91'), findsNothing);
  });

  group('module', () {
    const bug = ZenTaoBugEntity(product: '4', module: '361');

    testWidgets('shows the module path once the names load', (tester) async {
      when(() => editor.bugOptions('zt', productId: '4')).thenAnswer(
        (_) async => const Ok(
          BugFormOptions(
            modules: [FormOption(value: '361', label: '/Livestream/Share')],
          ),
        ),
      );
      await pump(tester, bug);
      expect(find.text('Livestream/Share'), findsOneWidget);
      expect(find.text('361'), findsNothing);
    });

    testWidgets('keeps the module id when the names cannot load', (
      tester,
    ) async {
      when(
        () => editor.bugOptions('zt', productId: '4'),
      ).thenAnswer((_) async => const Err(NetworkFailure('offline')));
      await pump(tester, bug);
      expect(find.text('361'), findsOneWidget);
      expect(find.text('Livestream/Share'), findsNothing);
    });
  });

  testWidgets('the task row links to the task by name and id', (tester) async {
    await pump(
      tester,
      const ZenTaoBugEntity(task: '11548', taskName: 'TaskName'),
    );
    expect(
      find.descendant(
        of: find.byType(ZenTaoLinkedTicket),
        matching: find.text('TaskName · #11548'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping the execution opens its board', (tester) async {
    final opened = <ProviderExecution>[];
    await pump(
      tester,
      const ZenTaoBugEntity(
        project: '7',
        execution: '91',
        executionName: 'Sprint 12',
      ),
      openExecution: (context, ref, execution) async => opened.add(execution),
    );
    await tester.tap(find.text('Sprint 12'));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    final execution = opened.single;
    expect(execution.id, '91');
    expect(execution.name, 'Sprint 12');
    expect(execution.projectId, '7');
    expect(execution.accountId, 'zt');
  });
}

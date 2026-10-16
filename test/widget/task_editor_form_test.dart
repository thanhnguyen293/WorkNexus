import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/zentao_ticket_editor.dart';
import 'package:work_nexus/core/domain/entities/zentao_ticket_form.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/navigation/ticket_editor_route.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/rich_text_editor.dart';
import 'package:work_nexus/features/ticket_editor/presentation/pages/ticket_editor_page.dart';
import 'package:work_nexus/features/ticket_editor/presentation/providers/ticket_draft_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/fake_ticket_draft_repository.dart';

class _MockEditor extends Mock implements ZenTaoTicketEditor {}

const _editRoute = EditTaskRoute(
  accountId: 'zt',
  taskId: '12',
  ticketId: 'zt:task:12',
);
const _newRoute = NewTaskRoute(accountId: 'zt', executionId: '5');

const _options = TaskFormOptions(
  executions: [FormOption(value: '5', label: 'Sprint 5')],
  modules: [FormOption(value: '7', label: 'Login')],
);

const _editForm = TaskForm(
  draft: TaskDraft(
    id: '12',
    execution: '5',
    name: 'Fix login',
    status: 'doing',
    consumed: 3,
    left: 2,
  ),
  options: _options,
);

const _newForm = TaskForm(
  draft: TaskDraft(execution: '5'),
  options: _options,
);

void main() {
  late _MockEditor editor;

  setUpAll(() {
    registerFallbackValue(_editForm);
    registerFallbackValue(const TaskDraft(execution: '5'));
  });

  setUp(() {
    editor = _MockEditor();
    when(
      () => editor.editTaskForm('zt', '12'),
    ).thenAnswer((_) async => const Ok(_editForm));
    when(
      () => editor.newTaskForm(
        'zt',
        '5',
        parentId: any(named: 'parentId'),
        copyOf: any(named: 'copyOf'),
      ),
    ).thenAnswer((_) async => const Ok(_newForm));
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    TicketEditorRoute route,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        zenTaoTicketEditorProvider.overrideWithValue(editor),
        ticketDraftRepositoryProvider.overrideWithValue(
          FakeTicketDraftRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(appNavProvider.notifier).openEditor(route);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: const [
            ...AppL10n.localizationsDelegates,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TicketEditorPage(
                route: ref.watch(ticketEditorProvider) ?? route,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('editing a task offers its status, hours and colour', (
    tester,
  ) async {
    await pump(tester, _editRoute);

    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Consumed (h)'), findsOneWidget);
    expect(find.text('Left (h)'), findsOneWidget);
    expect(find.text('Colour'), findsOneWidget);
    // The after-save choice is the create form's.
    expect(find.text('After saving'), findsNothing);
  });

  testWidgets('the status and hours typed are what is saved', (tester) async {
    when(
      () => editor.saveTask('zt', any(), any(), uid: any(named: 'uid')),
    ).thenAnswer((_) async => const Ok('zt:task:12'));
    await pump(tester, _editRoute);

    final left = find.ancestor(
      of: find.text('Left (h)'),
      matching: find.byType(Column),
    );
    await tester.enterText(
      find.descendant(of: left.first, matching: find.byType(TextField)),
      '1.5',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final draft =
        verify(
              () => editor.saveTask(
                'zt',
                any(),
                captureAny(),
                uid: any(named: 'uid'),
              ),
            ).captured.single
            as TaskDraft;
    expect(draft.left, 1.5);
    expect(draft.consumed, 3);
    expect(draft.status, 'doing');
  });

  testWidgets('simple mode hides the optional fields', (tester) async {
    await pump(tester, _newRoute);
    expect(find.text('Module'), findsOneWidget);

    await tester.tap(find.text('Simple'));
    await tester.pumpAndSettle();

    expect(find.text('Module'), findsNothing);
    expect(find.text('Colour'), findsNothing);
    expect(find.text('Assign to'), findsOneWidget);
  });

  testWidgets('"Add another task" opens an empty form after saving', (
    tester,
  ) async {
    when(
      () => editor.saveTask('zt', any(), any(), uid: any(named: 'uid')),
    ).thenAnswer((_) async => const Ok('zt:task:13'));
    final container = await pump(tester, _newRoute);

    await tester.enterText(find.byType(TextField).first, 'Write docs');
    tester
        .widget<RichTextEditor>(find.byType(RichTextEditor))
        .controller
        .quill
        .document
        .insert(0, 'Old notes');
    await tester.tap(find.text('Add another task'));
    await tester.pumpAndSettle();
    // The header's Save follows the choice too.
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(container.read(ticketEditorProvider), _newRoute);
    // A fresh form: neither the name nor the description carries over.
    expect(find.text('Write docs'), findsNothing);
    expect(
      tester
          .widget<RichTextEditor>(find.byType(RichTextEditor))
          .controller
          .quill
          .document
          .toPlainText()
          .trim(),
      isEmpty,
    );
    expect(container.read(openTicketIdProvider), isNull);
    verify(
      () => editor.newTaskForm(
        'zt',
        '5',
        parentId: any(named: 'parentId'),
        copyOf: any(named: 'copyOf'),
      ),
    ).called(2);
  });

  testWidgets('"Back to the list" closes the editor without opening the '
      'task', (tester) async {
    when(
      () => editor.saveTask('zt', any(), any(), uid: any(named: 'uid')),
    ).thenAnswer((_) async => const Ok('zt:task:13'));
    final container = await pump(tester, _newRoute);

    await tester.enterText(find.byType(TextField).first, 'Write docs');
    await tester.tap(find.text('Back to the list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(container.read(ticketEditorProvider), isNull);
    expect(container.read(openTicketIdProvider), isNull);
  });
}

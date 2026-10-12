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
import 'package:work_nexus/core/widgets/app_button.dart';
import 'package:work_nexus/features/ticket_editor/domain/entities/saved_ticket_draft.dart';
import 'package:work_nexus/features/ticket_editor/presentation/pages/ticket_editor_page.dart';
import 'package:work_nexus/features/ticket_editor/presentation/providers/ticket_draft_providers.dart';
import 'package:work_nexus/features/ticket_editor/presentation/widgets/editor_header.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/fake_ticket_draft_repository.dart';

class _MockEditor extends Mock implements ZenTaoTicketEditor {}

const _route = NewBugRoute(accountId: 'zt', productId: '4');

const _form = BugForm(
  draft: BugDraft(product: '4'),
  options: BugFormOptions(
    products: [FormOption(value: '4', label: 'VN_Socialfi')],
    builds: [FormOption(value: 'trunk', label: 'Trunk')],
  ),
);

void main() {
  late _MockEditor editor;
  late FakeTicketDraftRepository drafts;

  setUpAll(() {
    registerFallbackValue(_form);
    registerFallbackValue(const BugDraft(product: '4'));
  });

  setUp(() {
    editor = _MockEditor();
    drafts = FakeTicketDraftRepository();
    when(
      () => editor.newBugForm('zt', '4'),
    ).thenAnswer((_) async => const Ok(_form));
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    NewBugRoute route = _route,
  }) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        zenTaoTicketEditorProvider.overrideWithValue(editor),
        ticketDraftRepositoryProvider.overrideWithValue(drafts),
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
          home: Scaffold(body: TicketEditorPage(route: route)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a bug is not saved without its title', (tester) async {
    await pump(tester);

    expect(find.text('New bug'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget);
    verifyNever(
      () => editor.saveBug(any(), any(), any(), uid: any(named: 'uid')),
    );
  });

  testWidgets('saving opens the saved bug and closes the editor', (
    tester,
  ) async {
    when(
      () => editor.saveBug('zt', any(), any(), uid: any(named: 'uid')),
    ).thenAnswer((_) async => const Ok('zt:42'));
    final container = await pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Crash on login');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final draft =
        verify(
              () => editor.saveBug(
                'zt',
                any(),
                captureAny(),
                uid: any(named: 'uid'),
              ),
            ).captured.single
            as BugDraft;
    expect(draft.title, 'Crash on login');
    expect(container.read(openTicketIdProvider), 'zt:42');
    expect(container.read(ticketEditorProvider), isNull);
  });

  testWidgets('Cancel and Save sit at the right edge of the bar', (
    tester,
  ) async {
    await pump(tester);

    final bar = tester.getRect(find.byType(EditorHeader));
    final save = tester.getRect(find.widgetWithText(AppButton, 'Save'));
    final cancel = tester.getRect(find.widgetWithText(AppButton, 'Cancel'));
    // Only the bar's padding is right of Save; Cancel sits just before it.
    expect(bar.right - save.right, lessThan(40));
    expect(save.left - cancel.right, lessThan(20));
  });

  group('drafts', () {
    // Past the editor's pause before it keeps a change.
    const pause = Duration(seconds: 1);

    testWidgets('typing keeps a draft, which Cancel leaves in place', (
      tester,
    ) async {
      final container = await pump(tester);
      expect(find.text('Draft saved'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Crash on login');
      await tester.pump(pause);

      expect(find.text('Draft saved'), findsOneWidget);
      expect(drafts.all.single.title, 'Crash on login');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(ticketEditorProvider), isNull);
      expect(drafts.all, hasLength(1));
    });

    testWidgets('opening an untouched form keeps nothing', (tester) async {
      await pump(tester);
      await tester.pump(pause);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(drafts.all, isEmpty);
    });

    testWidgets('a kept draft reopens as it was left', (tester) async {
      await drafts.save(
        SavedTicketDraft.bug(
          id: 'd1',
          accountId: 'zt',
          uid: 'u1',
          updatedAt: DateTime(2026, 10, 12),
          draft: const BugDraft(product: '4', title: 'Half-written'),
        ),
      );

      await pump(
        tester,
        route: const NewBugRoute(
          accountId: 'zt',
          productId: '4',
          draftId: 'd1',
        ),
      );

      expect(find.text('Half-written'), findsOneWidget);
      expect(find.text('Draft saved'), findsOneWidget);
    });

    testWidgets('saving the bug deletes its draft', (tester) async {
      when(
        () => editor.saveBug('zt', any(), any(), uid: any(named: 'uid')),
      ).thenAnswer((_) async => const Ok('zt:42'));
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'Crash on login');
      await tester.pump(pause);
      expect(drafts.all, hasLength(1));

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(drafts.all, isEmpty);
    });

    testWidgets('discarding asks first, then deletes and closes', (
      tester,
    ) async {
      final container = await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'Crash on login');
      await tester.pump(pause);

      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this draft?'), findsOneWidget);
      await tester.tap(find.text('Discard draft').last);
      await tester.pumpAndSettle();

      expect(drafts.all, isEmpty);
      expect(container.read(ticketEditorProvider), isNull);
    });

    testWidgets('a draft that cannot be deleted keeps the editor open', (
      tester,
    ) async {
      final container = await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'Crash on login');
      await tester.pump(pause);
      drafts.failDeletes = true;

      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard draft').last);
      await tester.pumpAndSettle();

      expect(container.read(ticketEditorProvider), isNotNull);
      expect(drafts.all, hasLength(1));
      expect(find.textContaining('Could not keep the draft'), findsOneWidget);
    });

    testWidgets(
      'a draft that cannot be read shows an error, not a blank form',
      (tester) async {
        drafts.failReads = true;

        await pump(
          tester,
          route: const NewBugRoute(
            accountId: 'zt',
            productId: '4',
            draftId: 'd1',
          ),
        );

        expect(find.text("Couldn't load the form"), findsOneWidget);
        verifyNever(() => editor.newBugForm(any(), any()));
      },
    );
  });
}

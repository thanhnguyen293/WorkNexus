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
import 'package:work_nexus/features/ticket_editor/presentation/pages/ticket_editor_page.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

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

  setUpAll(() {
    registerFallbackValue(_form);
    registerFallbackValue(const BugDraft(product: '4'));
  });

  setUp(() {
    editor = _MockEditor();
    when(
      () => editor.newBugForm('zt', '4'),
    ).thenAnswer((_) async => const Ok(_form));
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [zenTaoTicketEditorProvider.overrideWithValue(editor)],
    );
    addTearDown(container.dispose);
    container.read(ticketEditorProvider.notifier).open(_route);
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
          home: const Scaffold(body: TicketEditorPage(route: _route)),
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
}

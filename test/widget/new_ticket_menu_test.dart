import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/new_ticket_menu.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/navigation/ticket_editor_route.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_rail_button.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const _zentao = Account(
  id: 'zt',
  workspaceId: 'w',
  providerType: ProviderType.zentao,
  handle: 'thanh',
);

const _gitlab = Account(
  id: 'gl',
  workspaceId: 'w',
  providerType: ProviderType.gitlab,
  handle: 'thanh',
);

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<Account> accounts,
  ) async {
    final container = ProviderContainer(
      overrides: [
        lookupsProvider.overrideWithValue((
          accounts: {for (final a in accounts) a.id: a},
          workspaces: const {},
          projects: const {},
        )),
      ],
    );
    addTearDown(container.dispose);
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
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(
            body: NewTicketShortcut(
              child: Align(
                alignment: Alignment.topLeft,
                child: NewTicketRailButton(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('there is no "+" without a ZenTao account', (tester) async {
    await pump(tester, const [_gitlab]);

    expect(find.byType(AppRailButton), findsNothing);
  });

  testWidgets('"+" opens a new task in the editor, from anywhere', (
    tester,
  ) async {
    final container = await pump(tester, const [_zentao, _gitlab]);
    container.read(openTicketIdProvider.notifier).open('zt:1');

    await tester.tap(find.byType(AppRailButton));
    await tester.pumpAndSettle();
    expect(find.text('New bug'), findsOneWidget);
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();

    // No board selection: ZenTao's current execution ('0'), changeable in
    // the editor; the open detail gives way to it.
    expect(
      container.read(ticketEditorProvider),
      const NewTaskRoute(accountId: 'zt'),
    );
    expect(container.read(openTicketIdProvider), isNull);
  });

  testWidgets('the keyboard shortcut opens the menu', (tester) async {
    await pump(tester, const [_zentao]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('New bug'), findsOneWidget);
    expect(find.text('New task'), findsOneWidget);
  });
}

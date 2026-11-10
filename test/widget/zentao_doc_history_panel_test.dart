import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_action.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_change.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_doc_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_history_button.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_history_panel.dart';

const _account = Account(
  id: 'a1',
  workspaceId: 'w1',
  providerType: ProviderType.zentao,
  handle: 'thanh',
);

void main() {
  testWidgets('entries read in the app language; + shows what changed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          zentaoDocHistorySyncProvider.overrideWith((ref, key) async {}),
          zentaoDocHistoryProvider.overrideWith(
            (ref, key) => Stream.value([
              ZenTaoDocAction(
                id: '1',
                action: 'saveddraft',
                summary: 'Vi save draft',
                actor: 'Vi',
                date: DateTime(2026, 7, 22, 17, 58),
              ),
              const ZenTaoDocAction(
                id: '2',
                action: 'edited',
                summary: 'edited by Saul',
                actor: 'Saul',
                changes: [
                  ZenTaoDocChange(
                    field: 'Status',
                    from: 'Draft',
                    to: 'Released',
                  ),
                  ZenTaoDocChange(field: 'rawContent', isBody: true),
                ],
              ),
              const ZenTaoDocAction(
                id: '3',
                action: 'approved',
                summary: 'approved by Saul',
                actor: 'Saul',
              ),
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
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 600,
              child: ZenTaoDocHistoryPanel(
                account: _account,
                docId: '111',
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vi saved a draft', findRichText: true), findsOneWidget);
    expect(find.text('Saul edited it', findRichText: true), findsOneWidget);
    // An action the app doesn't name reads as ZenTao wrote it.
    expect(find.text('approved by Saul', findRichText: true), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    expect(find.text('Status'), findsNothing);
    await tester.tap(find.byTooltip('Show what changed'));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
    expect(find.textContaining('Draft', findRichText: true), findsOneWidget);
    // The body is only said to have changed: no raw page JSON.
    expect(find.text("The document's content changed"), findsOneWidget);
  });

  testWidgets(
    'the history pops over from its button; a tap outside closes it',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            zentaoDocHistorySyncProvider.overrideWith((ref, key) async {}),
            zentaoDocHistoryProvider.overrideWith(
              (ref, key) => Stream.value(const [
                ZenTaoDocAction(
                  id: '1',
                  action: 'edited',
                  summary: 'edited by Saul',
                  actor: 'Saul',
                ),
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
              body: Align(
                alignment: Alignment.topRight,
                child: ZenTaoDocHistoryButton(account: _account, docId: '111'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Saul edited it', findRichText: true), findsNothing);
      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();
      expect(find.text('Saul edited it', findRichText: true), findsOneWidget);

      // As tall as its one entry, clear of the window's right edge.
      final card = tester.getRect(find.byType(ZenTaoDocHistoryPanel));
      final window = tester.getRect(find.byType(Scaffold));
      expect(card.height, lessThan(window.height * 0.5));
      expect(card.right, lessThan(window.right));

      await tester.tapAt(const Offset(20, 500));
      await tester.pumpAndSettle();
      expect(find.text('Saul edited it', findRichText: true), findsNothing);
    },
    // On the desktop, as the app runs: a mobile platform would hand the
    // popover's scroll views one shared primary controller.
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'a document without history still opens its popover',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            zentaoDocHistorySyncProvider.overrideWith((ref, key) async {}),
            zentaoDocHistoryProvider.overrideWith(
              (ref, key) => Stream.value(const <ZenTaoDocAction>[]),
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
              body: Align(
                alignment: Alignment.topRight,
                child: ZenTaoDocHistoryButton(account: _account, docId: '1'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No history yet'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

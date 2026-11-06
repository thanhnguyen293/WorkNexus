import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/providers/board_providers.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/build_zentao_module_tree.dart';
import 'package:work_nexus/tools/zentao/presentation/nav/zentao_bug_module_pane.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_module_tree_provider.dart';

import '../support/di_test_harness.dart';

const _account = Account(
  id: 'acc-zt',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'dev_zt',
  baseUrl: 'https://zentao.corp.net',
);

/// The Bugs side panel: the open product, then its module tree; a module
/// picked there narrows the board to it, All modules clears it.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator(seed: false));
  tearDown(() async => resetTestLocator(db));

  testWidgets('picking a module filters the board; All clears it', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        zentaoProductsProvider('acc-zt').overrideWith(
          (ref) => Stream.value(const [
            ProviderProduct(id: '4', name: 'VN_Socialfi', accountId: 'acc-zt'),
          ]),
        ),
        zentaoModuleTreeProvider(true).overrideWithValue(
          const AsyncData(
            ZenTaoModuleTree(
              total: 8,
              nodes: [
                ZenTaoModuleNode(
                  id: '1',
                  name: 'Live stream',
                  depth: 0,
                  count: 1,
                ),
                ZenTaoModuleNode(id: '2', name: 'Share', depth: 1, count: 2),
                ZenTaoModuleNode(id: '3', name: 'Feed', depth: 0, count: 5),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              child: ZentaoBugModulePane(
                account: _account,
                location: ToolLocation(
                  section: SectionId('zentao.bugs'),
                  scopeId: '4',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VN_Socialfi'), findsOneWidget);
    // Any other product is a pick away.
    expect(find.text('Other products…'), findsOneWidget);
    expect(find.text('All modules'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();
    expect(container.read(filterStateProvider).modules, {'3'});

    await tester.tap(find.text('All modules'));
    await tester.pumpAndSettle();
    expect(container.read(filterStateProvider).modules, isEmpty);
    await disposeTree(tester);
  });

  testWidgets('opening a pinned product keeps the pinned order', (
    tester,
  ) async {
    Future<List<String>> rowsFor(String open) async {
      final container = ProviderContainer(
        overrides: [
          zentaoProductsProvider('acc-zt').overrideWith(
            (ref) => Stream.value(const [
              ProviderProduct(id: '4', name: 'Alpha', accountId: 'acc-zt'),
              ProviderProduct(id: '5', name: 'Beta', accountId: 'acc-zt'),
            ]),
          ),
          zentaoModuleTreeProvider(
            true,
          ).overrideWithValue(const AsyncData(ZenTaoModuleTree.empty)),
        ],
      );
      addTearDown(container.dispose);
      final settings = container.read(appSettingsProvider.notifier);
      if (!container
          .read(appSettingsProvider)
          .pinnedProjects
          .contains('acc-zt:4')) {
        settings
          ..togglePinnedProject('acc-zt:4')
          ..togglePinnedProject('acc-zt:5');
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            theme: buildAppTheme(
              variant: AppThemeVariant.light,
              surface: SurfaceStyle.outline,
              density: AppDensity.comfortable,
            ),
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: ZentaoBugModulePane(
                  account: _account,
                  location: ToolLocation(
                    section: const SectionId('zentao.bugs'),
                    scopeId: open,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      return (['Alpha', 'Beta']..sort((a, b) => top(a).compareTo(top(b))));
    }

    expect(await rowsFor('4'), ['Alpha', 'Beta']);
    expect(await rowsFor('5'), ['Alpha', 'Beta']);
    await disposeTree(tester);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/util/keep_bug_board_product.dart';

const _account = Account(
  id: 'zt',
  workspaceId: 'w',
  providerType: ProviderType.zentao,
  handle: 'me',
);

const _products = [
  ProviderProduct(id: '1', name: 'First', accountId: 'zt'),
  ProviderProduct(id: '2', name: 'Pinned', accountId: 'zt'),
];

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Set<String> pinned = const {},
    String? scope,
  }) async {
    final container = ProviderContainer(
      overrides: [
        zentaoProductsProvider(
          'zt',
        ).overrideWith((ref) => Stream.value(_products)),
        initialAppSettingsProvider.overrideWithValue(
          AppSettings(pinnedProjects: pinned),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(appNavProvider.notifier)
      ..selectAccount('zt')
      ..selectSection(const SectionId('zentao.bugs'))
      ..selectScope(scope);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final location = ref.watch(currentToolLocationProvider);
            if (location != null) {
              keepBugBoardProduct(context, ref, _account, location);
            }
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('without a product the board takes a pinned one', (tester) async {
    final container = await pump(tester, pinned: {'zt:2'});

    expect(container.read(currentToolLocationProvider)?.scopeId, '2');
    expect(container.read(selectedZenTaoProductProvider)?.productId, '2');
  });

  testWidgets('else the first product', (tester) async {
    final container = await pump(tester);

    expect(container.read(currentToolLocationProvider)?.scopeId, '1');
    expect(container.read(selectedZenTaoProductProvider)?.productId, '1');
  });

  testWidgets('a product that is gone gives way to another', (tester) async {
    final container = await pump(tester, scope: '99');

    expect(container.read(currentToolLocationProvider)?.scopeId, '1');
  });

  testWidgets('the scope\'s product is the one selected', (tester) async {
    final container = await pump(tester, scope: '2');

    expect(container.read(currentToolLocationProvider)?.scopeId, '2');
    expect(container.read(selectedZenTaoProductProvider)?.productId, '2');
  });
}

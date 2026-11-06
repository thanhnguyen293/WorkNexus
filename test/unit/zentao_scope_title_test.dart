import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_scope_title_provider.dart';

void main() {
  const product = ProviderProduct(
    id: 'p-1',
    name: 'VN_Socialfi',
    accountId: 'acc',
  );
  const execution = ProviderExecution(
    id: 'e-1',
    name: 'Sprint 12',
    projectId: 'pj-1',
    accountId: 'acc',
  );

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        zentaoProductsProvider.overrideWith(
          (ref, accountId) => Stream.value(const [product]),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a bug board is titled by the picked product', () {
    final c = container();
    c.read(selectedZenTaoProductProvider.notifier).select(product);

    expect(
      c.read(
        zentaoScopeTitleProvider((
          accountId: 'acc',
          scopeId: 'p-1',
          bugs: true,
        )),
      ),
      'VN_Socialfi',
    );
  });

  test(
    'a bug board not yet picked is titled by its product from the list',
    () async {
      final c = container();
      const key = (accountId: 'acc', scopeId: 'p-1', bugs: true);
      final sub = c.listen(zentaoScopeTitleProvider(key), (_, _) {});
      addTearDown(sub.close);
      await c.read(zentaoProductsProvider('acc').future);

      expect(c.read(zentaoScopeTitleProvider(key)), 'VN_Socialfi');
    },
  );

  test('a selection of another account or scope is not the title', () {
    final c = container();
    c.read(selectedZenTaoProductProvider.notifier).select(product);
    c.read(selectedZenTaoExecutionProvider.notifier).select(execution);

    expect(
      c.read(
        zentaoScopeTitleProvider((
          accountId: 'other',
          scopeId: 'p-1',
          bugs: true,
        )),
      ),
      isNull,
    );
    expect(
      c.read(
        zentaoScopeTitleProvider((
          accountId: 'acc',
          scopeId: 'e-2',
          bugs: false,
        )),
      ),
      isNull,
    );
  });

  test('a task board is titled by the picked execution', () {
    final c = container();
    c.read(selectedZenTaoExecutionProvider.notifier).select(execution);

    expect(
      c.read(
        zentaoScopeTitleProvider((
          accountId: 'acc',
          scopeId: 'e-1',
          bugs: false,
        )),
      ),
      'Sprint 12',
    );
  });
}

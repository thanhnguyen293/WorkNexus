import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/tools/zentao/data/models/zentao_models.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_product_group.dart';

/// `GET /products?mergeChildren=1` as ZenTao's `mergeChildren()` shapes it:
/// a program with a line and a bare product, a top-level line, programless
/// products — each product with its own `type` (normal / branch / platform).
const _tree = {
  'page': 1,
  'total': 5,
  'limit': 100,
  'products': [
    {
      'id': 1,
      'name': 'VN Program',
      'type': 'program',
      'unclosedTotal': 4,
      'children': [
        {
          'id': 30,
          'name': 'Mobile',
          'type': 'line',
          'children': [
            {'id': 12, 'name': 'Wallet', 'type': 'normal'},
            {'id': 13, 'name': 'Chat', 'type': 'branch'},
          ],
        },
        {'id': 14, 'name': 'Website', 'type': 'platform'},
      ],
    },
    {
      'id': 31,
      'name': 'Tools',
      'type': 'line',
      // PHP's keyed arrays come as JSON objects.
      'children': {
        '15': {'id': 15, 'name': 'Code Security Review', 'type': 'normal'},
      },
    },
    {'id': 16, 'name': 'Daily Work Log', 'type': 'normal'},
    {'id': 17, 'name': 'Archive', 'type': 'normal'},
  ],
};

ProviderProduct _provider(ZenTaoProduct p) => ProviderProduct(
  id: p.id,
  name: p.name,
  accountId: 'zt',
  programId: p.programId,
  programName: p.programName,
  lineId: p.lineId,
  lineName: p.lineName,
);

void main() {
  test('the merged tree reads as products filed under program and line', () {
    final products = ZenTaoProductsResponse.fromJson(_tree).products;

    expect(
      [for (final p in products) (p.id, p.name, p.programName, p.lineName)],
      [
        ('12', 'Wallet', 'VN Program', 'Mobile'),
        ('13', 'Chat', 'VN Program', 'Mobile'),
        ('14', 'Website', 'VN Program', null),
        ('15', 'Code Security Review', null, 'Tools'),
        ('16', 'Daily Work Log', null, null),
        ('17', 'Archive', null, null),
      ],
    );
  });

  test('products group by program, then line, in ZenTao\'s order', () {
    final tree = ZenTaoProductTree.of([
      for (final p in ZenTaoProductsResponse.fromJson(_tree).products)
        _provider(p),
    ]);

    expect(tree.groups.map((g) => (g.id, g.name)), [
      ('program:1', 'VN Program'),
      ('line:31', 'Tools'),
    ]);
    final program = tree.groups.first;
    expect(program.lines.single.name, 'Mobile');
    expect(program.lines.single.products.map((p) => p.name), [
      'Wallet',
      'Chat',
    ]);
    expect(program.products.map((p) => p.name), ['Website']);
    expect(program.allProducts.map((p) => p.id), ['12', '13', '14']);
    // No folder made up from a name: "Code …" stays in its real line.
    expect(tree.groups.last.products.single.name, 'Code Security Review');
    // The loose products read by name; folders keep ZenTao's order.
    expect(tree.ungrouped.map((p) => p.name), ['Archive', 'Daily Work Log']);
  });

  test('a plain list (no tree) stays flat, sorted by name', () {
    final plain = ZenTaoProductsResponse.fromJson(const {
      'total': 2,
      'products': [
        {'id': 2, 'name': 'Wallet', 'type': 'normal', 'program': 1},
        {'id': 1, 'name': 'Chat', 'type': 'normal'},
      ],
    }).products;
    final tree = ZenTaoProductTree.of([for (final p in plain) _provider(p)]);

    expect(tree.groups, isEmpty);
    expect(tree.ungrouped.map((p) => p.name), ['Chat', 'Wallet']);
  });
}

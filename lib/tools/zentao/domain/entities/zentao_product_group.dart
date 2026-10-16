import '../../../../core/domain/adapters/provider_adapter.dart';

/// A folder of the ZenTao products tree: a program (with its product lines
/// as sub-folders) or a product line on its own — ZenTao's own grouping, as
/// its products reply files each product ([ProviderProduct.programId],
/// [ProviderProduct.lineId]).
class ZenTaoProductGroup {
  const ZenTaoProductGroup({
    required this.id,
    required this.name,
    required this.products,
    this.lines = const [],
  });

  /// `program:<id>` or `line:<id>`.
  final String id;

  final String name;

  /// The products filed directly here (a program's products outside a line).
  final List<ProviderProduct> products;

  /// A program's product lines, each a folder of its products.
  final List<ZenTaoProductGroup> lines;

  /// Every product in the folder, its lines' included.
  Iterable<ProviderProduct> get allProducts => [
    for (final line in lines) ...line.allProducts,
    ...products,
  ];
}

/// The products as ZenTao groups them: [groups] in ZenTao's order, then the
/// products in no program or line ([ungrouped]).
class ZenTaoProductTree {
  const ZenTaoProductTree({required this.groups, required this.ungrouped});

  final List<ZenTaoProductGroup> groups;
  final List<ProviderProduct> ungrouped;

  /// Builds the tree from [products] in the order ZenTao listed them. When
  /// none carries a program or line — an older server, or the plain list —
  /// they stay one flat list, sorted by name: no folder is ever made up.
  factory ZenTaoProductTree.of(List<ProviderProduct> products) {
    final grouped = products.any(
      (p) => p.programId != null || p.lineId != null,
    );
    if (!grouped) {
      return ZenTaoProductTree(
        groups: const [],
        ungrouped: [
          ...products,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );
    }
    final folders = <String, _Folder>{};
    final ungrouped = <ProviderProduct>[];
    for (final p in products) {
      final programId = p.programId;
      final lineId = p.lineId;
      if (programId != null) {
        final program = folders.putIfAbsent(
          'program:$programId',
          () => _Folder('program:$programId', p.programName ?? programId),
        );
        if (lineId == null) {
          program.products.add(p);
        } else {
          program.lines
              .putIfAbsent(
                'line:$lineId',
                () => _Folder('line:$lineId', p.lineName ?? lineId),
              )
              .products
              .add(p);
        }
      } else if (lineId != null) {
        folders
            .putIfAbsent(
              'line:$lineId',
              () => _Folder('line:$lineId', p.lineName ?? lineId),
            )
            .products
            .add(p);
      } else {
        ungrouped.add(p);
      }
    }
    return ZenTaoProductTree(
      groups: [for (final f in folders.values) f.toGroup()],
      ungrouped: ungrouped,
    );
  }
}

class _Folder {
  _Folder(this.id, this.name);

  final String id;
  final String name;
  final products = <ProviderProduct>[];
  final lines = <String, _Folder>{};

  ZenTaoProductGroup toGroup() => ZenTaoProductGroup(
    id: id,
    name: name,
    products: products,
    lines: [for (final l in lines.values) l.toGroup()],
  );
}

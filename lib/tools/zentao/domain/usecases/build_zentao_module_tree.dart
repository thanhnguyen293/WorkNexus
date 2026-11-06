import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/usecase/usecase.dart';

/// A row of the module tree: the module's own [name] (the last part of its
/// path), how deep it sits ([depth] 0 for a top-level module) and how many of
/// the board's bugs sit in it ([count]).
class ZenTaoModuleNode {
  const ZenTaoModuleNode({
    required this.id,
    required this.name,
    required this.depth,
    required this.count,
  });

  final String id;
  final String name;
  final int depth;
  final int count;
}

/// The module tree and how many bugs the board shows over all modules
/// ([total], the "All modules" row).
class ZenTaoModuleTree {
  const ZenTaoModuleTree({required this.nodes, required this.total});

  final List<ZenTaoModuleNode> nodes;
  final int total;

  static const empty = ZenTaoModuleTree(nodes: [], total: 0);
}

/// Input for [BuildZenTaoModuleTree]: the product's module [paths] (id →
/// "Live stream/Share", in ZenTao's order), the board's [bugs] with every
/// filter but the module one applied, whether to [hideEmpty] modules, and the
/// [selected] module id (kept whatever its count, so a pick never vanishes
/// from under the cursor).
class ZenTaoModuleTreeInput {
  const ZenTaoModuleTreeInput({
    required this.paths,
    required this.bugs,
    this.hideEmpty = false,
    this.selected,
  });

  final Map<String, String> paths;
  final List<Ticket> bugs;
  final bool hideEmpty;
  final String? selected;
}

/// The bug board's module tree, like the one beside ZenTao's own bug list:
/// each module named by the last part of its path, indented under its
/// parents, with the count of bugs the board would show on picking it.
/// Hiding empty modules keeps a parent whose sub-modules have bugs, so a busy
/// sub-module never loses its place. ZenTao's "no module" ('0') is not listed.
class BuildZenTaoModuleTree
    extends UseCase<ZenTaoModuleTree, ZenTaoModuleTreeInput> {
  const BuildZenTaoModuleTree();

  @override
  ZenTaoModuleTree call(ZenTaoModuleTreeInput input) {
    final counts = <String, int>{};
    for (final bug in input.bugs) {
      if (bug.providerEntity case ZenTaoBugEntity(:final module?)) {
        counts[module] = (counts[module] ?? 0) + 1;
      }
    }
    final modules = [
      for (final e in input.paths.entries)
        if (e.key != '0' && _parts(e.value).isNotEmpty)
          (id: e.key, parts: _parts(e.value), count: counts[e.key] ?? 0),
    ];
    final busyPaths = <String>{};
    for (final m in modules) {
      if (m.count == 0 && m.id != input.selected) continue;
      for (var i = 1; i <= m.parts.length; i++) {
        busyPaths.add(m.parts.take(i).join('/'));
      }
    }
    return ZenTaoModuleTree(
      total: input.bugs.length,
      nodes: [
        for (final m in modules)
          if (!input.hideEmpty || busyPaths.contains(m.parts.join('/')))
            ZenTaoModuleNode(
              id: m.id,
              name: m.parts.last,
              depth: m.parts.length - 1,
              count: m.count,
            ),
      ],
    );
  }

  List<String> _parts(String path) => [
    for (final p in path.split('/'))
      if (p.trim().isNotEmpty) p.trim(),
  ];
}

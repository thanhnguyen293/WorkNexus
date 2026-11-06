import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_module_of.dart';
import '../../../../core/usecase/usecase.dart';

/// A row of the module tree: the module's own [name] (the last part of its
/// path), how deep it sits ([depth] 0 for a top-level module) and how many of
/// the board's bugs or tasks sit in it ([count]).
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

/// The module tree and how many tickets the board shows over all modules
/// ([total], the "All modules" row).
class ZenTaoModuleTree {
  const ZenTaoModuleTree({required this.nodes, required this.total});

  final List<ZenTaoModuleNode> nodes;
  final int total;

  static const empty = ZenTaoModuleTree(nodes: [], total: 0);
}

/// Input for [BuildZenTaoModuleTree]: the product's module [paths] (id →
/// "Live stream/Share", in ZenTao's order), the board's [tickets] (bugs or
/// tasks) with every
/// filter but the module one applied, whether to [hideEmpty] modules, and the
/// [selected] module id (kept whatever its count, so a pick never vanishes
/// from under the cursor).
class ZenTaoModuleTreeInput {
  const ZenTaoModuleTreeInput({
    required this.paths,
    required this.tickets,
    this.hideEmpty = false,
    this.selected,
  });

  final Map<String, String> paths;
  final List<Ticket> tickets;
  final bool hideEmpty;
  final String? selected;
}

/// A ZenTao board's module tree, like the one beside ZenTao's own bug and
/// task lists:
/// each module named by the last part of its path, indented under its
/// parents, with the count of tickets the board would show on picking it.
/// Hiding empty modules keeps a parent whose sub-modules have tickets, so a busy
/// sub-module never loses its place. ZenTao's "no module" ('0') is not listed.
class BuildZenTaoModuleTree
    extends UseCase<ZenTaoModuleTree, ZenTaoModuleTreeInput> {
  const BuildZenTaoModuleTree();

  @override
  ZenTaoModuleTree call(ZenTaoModuleTreeInput input) {
    final counts = <String, int>{};
    for (final ticket in input.tickets) {
      if (zentaoModuleOf(ticket) case final module?) {
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
      total: input.tickets.length,
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

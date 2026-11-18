import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/usecase/usecase.dart';

/// One subtask in its family tree: the [subtask] and its own [children], in
/// the order ZenTao listed them.
class SubtaskNode {
  SubtaskNode({required this.subtask, List<SubtaskNode> children = const []})
    : children = List.unmodifiable(children);

  final TicketSubtask subtask;
  final List<SubtaskNode> children;

  bool get hasChildren => children.isNotEmpty;
}

/// A task's subtasks as a tree: its direct subtasks ([roots]), each holding
/// its own, and how many subtasks there are at every level ([total]).
class SubtaskTree {
  SubtaskTree({required List<SubtaskNode> roots, required this.total})
    : roots = List.unmodifiable(roots);

  final List<SubtaskNode> roots;
  final int total;

  /// Whether any direct subtask has subtasks of its own.
  bool get isNested => roots.any((n) => n.hasChildren);
}

/// Input for [BuildSubtaskTree]: the open task's [parentId] and the
/// [subtasks] ZenTao listed on it (every descendant, flat).
class SubtaskTreeInput {
  const SubtaskTreeInput({required this.parentId, required this.subtasks});

  final String parentId;
  final List<TicketSubtask> subtasks;
}

/// Nests a task's flat subtask list by each subtask's parent. A subtask whose
/// parent is the task itself, unknown, or not in the list is a direct
/// subtask, so nothing ZenTao listed ever goes missing — including subtasks
/// whose parents loop back on each other, which join the direct ones.
class BuildSubtaskTree extends UseCase<SubtaskTree, SubtaskTreeInput> {
  const BuildSubtaskTree();

  @override
  SubtaskTree call(SubtaskTreeInput input) {
    final subtasks = input.subtasks;
    final ids = {for (final s in subtasks) s.id};
    final childrenOf = <String, List<TicketSubtask>>{};
    final roots = <TicketSubtask>[];
    for (final s in subtasks) {
      final parent = s.parentId;
      final nested =
          parent != null &&
          parent != input.parentId &&
          parent != s.id &&
          ids.contains(parent);
      if (nested) {
        (childrenOf[parent] ??= []).add(s);
      } else {
        roots.add(s);
      }
    }

    final placed = <String>{};
    SubtaskNode build(TicketSubtask s) {
      placed.add(s.id);
      return SubtaskNode(
        subtask: s,
        children: [
          for (final child in childrenOf[s.id] ?? const <TicketSubtask>[])
            if (!placed.contains(child.id)) build(child),
        ],
      );
    }

    final nodes = [for (final s in roots) build(s)];
    // A parent loop never reaches a root; surface its members as direct
    // subtasks rather than dropping them.
    for (final s in subtasks) {
      if (!placed.contains(s.id)) nodes.add(build(s));
    }
    return SubtaskTree(roots: nodes, total: subtasks.length);
  }
}

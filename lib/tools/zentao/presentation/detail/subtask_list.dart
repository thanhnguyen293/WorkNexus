import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/section_label.dart';
import '../../domain/usecases/build_subtask_tree.dart';
import '../util/open_zentao_task.dart';
import 'subtask_row.dart';

/// A parent task's subtasks: its direct ones, each with its own subtasks
/// folded under a chevron (ZenTao lists every level flat). Tapping a row opens
/// that subtask in the detail panel (fetched from ZenTao first when not
/// synced).
class SubtaskList extends ConsumerStatefulWidget {
  const SubtaskList({super.key, required this.ticket, required this.subtasks});

  /// The parent task.
  final Ticket ticket;
  final List<TicketSubtask> subtasks;

  @override
  ConsumerState<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends ConsumerState<SubtaskList> {
  /// The subtask being fetched to open, if any.
  String? _opening;

  /// The subtasks whose own subtasks are showing; all folded at first.
  final _expanded = <String>{};

  late SubtaskTree _tree = _build();

  SubtaskTree _build() => const BuildSubtaskTree()(
    SubtaskTreeInput(
      parentId: widget.ticket.externalKey,
      subtasks: widget.subtasks,
    ),
  );

  @override
  void didUpdateWidget(SubtaskList old) {
    super.didUpdateWidget(old);
    if (old.ticket.id != widget.ticket.id) _expanded.clear();
    if (old.ticket.externalKey != widget.ticket.externalKey ||
        old.subtasks != widget.subtasks) {
      _tree = _build();
    }
  }

  Future<void> _open(String id) async {
    final l = AppL10n.of(context);
    setState(() => _opening = id);
    final res = await openZenTaoTask(ref, widget.ticket, id);
    if (!mounted) return;
    setState(() => _opening = null);
    if (res case Err(:final failure)) {
      showAppSnack(context, l.actionFailed(failure.message), isError: true);
    }
  }

  void _toggle(String id) => setState(() {
    if (!_expanded.remove(id)) _expanded.add(id);
  });

  /// The rows showing now, depth first: a subtask's own subtasks follow it
  /// only while it is expanded.
  Iterable<(SubtaskNode, int)> _visible(List<SubtaskNode> nodes, int depth) =>
      nodes.expand(
        (n) => [
          (n, depth),
          if (_expanded.contains(n.subtask.id))
            ..._visible(n.children, depth + 1),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final tree = _tree;
    final direct = tree.roots.length;
    final count = tree.total > direct
        ? l.subtaskCountNested(direct, tree.total)
        : '$direct';
    final rows = _visible(tree.roots, 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('${l.subtasks} ($count)'),
        SizedBox(height: context.spacing.md),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              for (final (i, (node, depth)) in rows.indexed) ...[
                if (i > 0) Divider(height: 1, color: c.border),
                SubtaskRow(
                  key: ValueKey(node.subtask.id),
                  task: node.subtask,
                  depth: depth,
                  showToggle: tree.isNested,
                  expanded: node.hasChildren
                      ? _expanded.contains(node.subtask.id)
                      : null,
                  onToggle: () => _toggle(node.subtask.id),
                  opening: _opening == node.subtask.id,
                  onTap: _opening == null ? () => _open(node.subtask.id) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

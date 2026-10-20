import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_board_status.dart';
import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/domain/value_objects/zentao_task_column.dart';
import '../../../../core/usecase/usecase.dart';

/// Which board the facets are derived for; selects which dimensions apply.
enum BoardFacetScope { bug, task, gitlabMergeRequest, none }

/// A filterable dimension of a board.
enum BoardFacetKind {
  status,
  assignee,
  resolvedBy,
  openedBy,
  confirmed,
  reviewer,
  severity,
  priority,
  bugType,
  resolution,
}

/// One option within a facet group: its canonical [value] (the exact string/int
/// stored in `FilterState`), how many scoped tickets carry it, and — when the
/// [BoardFacetCatalog] names it — the [label] to show.
class BoardFacetOption {
  const BoardFacetOption({
    required this.value,
    required this.count,
    this.label,
  });

  final String value;
  final int count;
  final String? label;
}

/// A choice a board can be filtered by whether or not a loaded ticket carries
/// it yet: its canonical [value] and, when the value is not readable itself
/// (a login), the [label] to show.
class BoardFacetChoice {
  const BoardFacetChoice(this.value, {this.label});

  final String value;
  final String? label;
}

/// Every choice of each dimension, as the tool that owns the board knows them
/// (all of a ZenTao product's members, all its severities), so a filter can
/// name one no loaded ticket has yet. A dimension it leaves out is derived from
/// the tickets alone.
class BoardFacetCatalog {
  const BoardFacetCatalog(this.choices);

  final Map<BoardFacetKind, List<BoardFacetChoice>> choices;
}

/// A facet dimension plus its options, ordered by descending count.
class BoardFacetGroup {
  const BoardFacetGroup({required this.kind, required this.options});

  final BoardFacetKind kind;
  final List<BoardFacetOption> options;
}

/// The full set of facet groups available for a board.
class BoardFacets {
  const BoardFacets({required this.groups});

  final List<BoardFacetGroup> groups;

  static const empty = BoardFacets(groups: []);
}

/// Input for [DeriveBoardFacets]: the board-scoped tickets, the board kind and
/// the tool's [catalog] of every choice, if it has one.
class BoardFacetsInput {
  const BoardFacetsInput({
    required this.tickets,
    required this.scope,
    this.catalog,
  });

  final List<Ticket> tickets;
  final BoardFacetScope scope;
  final BoardFacetCatalog? catalog;
}

/// Derives the filter facets of a board. Assignee stores `''` for unassigned;
/// severity stores the int as a string; priority stores the [Priority] name;
/// bugType/resolution store the lowercased ZenTao code.
///
/// A dimension in the [BoardFacetsInput.catalog] lists every choice there, in
/// the catalog's order (with the count of tickets that carry it, 0 for none),
/// then any value the tickets carry that the catalog lacks. Any other
/// dimension lists what the tickets carry, and is dropped when that is fewer
/// than two values (it cannot narrow anything).
class DeriveBoardFacets extends UseCase<BoardFacets, BoardFacetsInput> {
  const DeriveBoardFacets();

  @override
  BoardFacets call(BoardFacetsInput input) {
    if (input.scope == BoardFacetScope.none) return BoardFacets.empty;
    final kinds = switch (input.scope) {
      // Status first: a table has no columns to tell them apart.
      BoardFacetScope.bug => const [
        BoardFacetKind.status,
        BoardFacetKind.assignee,
        BoardFacetKind.resolvedBy,
        BoardFacetKind.openedBy,
        BoardFacetKind.confirmed,
        BoardFacetKind.severity,
        BoardFacetKind.priority,
        BoardFacetKind.bugType,
        BoardFacetKind.resolution,
      ],
      BoardFacetScope.task => const [
        BoardFacetKind.status,
        BoardFacetKind.assignee,
        BoardFacetKind.priority,
      ],
      BoardFacetScope.gitlabMergeRequest => const [
        BoardFacetKind.assignee,
        BoardFacetKind.reviewer,
        BoardFacetKind.priority,
      ],
      BoardFacetScope.none => const <BoardFacetKind>[],
    };

    final groups = <BoardFacetGroup>[];
    for (final kind in kinds) {
      final counts = <String, int>{};
      for (final ticket in input.tickets) {
        for (final value in _valuesFor(kind, ticket)) {
          counts[value] = (counts[value] ?? 0) + 1;
        }
      }
      final known = input.catalog?.choices[kind];
      if (known == null && counts.length < 2) continue;
      final derived =
          [
            for (final e in counts.entries)
              if (known == null || !known.any((c) => c.value == e.key))
                BoardFacetOption(value: e.key, count: e.value),
          ]..sort(
            kind == BoardFacetKind.status
                // Statuses read in the board's column order.
                ? (a, b) =>
                      _statusOrder(a.value).compareTo(_statusOrder(b.value))
                : (a, b) => b.count.compareTo(a.count),
          );
      final options = [
        for (final c in known ?? const <BoardFacetChoice>[])
          BoardFacetOption(
            value: c.value,
            count: counts[c.value] ?? 0,
            label: c.label,
          ),
        ...derived,
      ];
      if (options.isEmpty) continue;
      groups.add(BoardFacetGroup(kind: kind, options: options));
    }
    return BoardFacets(groups: groups);
  }

  /// The canonical facet values for [kind] on [t]. Multi-user provider fields
  /// such as GitLab reviewers contribute one count to each user.
  List<String> _valuesFor(BoardFacetKind kind, Ticket t) {
    switch (kind) {
      case BoardFacetKind.status:
        final status = zentaoStatusOf(t);
        return status == null ? const [] : [status];
      case BoardFacetKind.resolvedBy:
        final e = t.providerEntity;
        final name = e is ZenTaoBugEntity ? (e.resolvedBy ?? '') : '';
        return name.isEmpty ? const [] : [name];
      case BoardFacetKind.openedBy:
        final e = t.providerEntity;
        final name = e is ZenTaoBugEntity ? (e.openedBy ?? '') : '';
        return name.isEmpty ? const [] : [name];
      case BoardFacetKind.confirmed:
        final e = t.providerEntity;
        return e is ZenTaoBugEntity ? ['${e.confirmed ?? 0}'] : const [];
      case BoardFacetKind.assignee:
        final e = t.providerEntity;
        if (e is GitLabItemEntity && e.assignees.isNotEmpty) {
          return e.assignees;
        }
        return [t.assignee ?? ''];
      case BoardFacetKind.reviewer:
        final e = t.providerEntity;
        return e is GitLabItemEntity && e.reviewers.isNotEmpty
            ? e.reviewers
            : const [''];
      case BoardFacetKind.severity:
        final value = t.severity?.toString();
        return value == null ? const [] : [value];
      case BoardFacetKind.priority:
        return [t.priority.name];
      case BoardFacetKind.bugType:
        final e = t.providerEntity;
        final code = e is ZenTaoBugEntity
            ? (e.bugType ?? '').toLowerCase()
            : '';
        return code.isEmpty ? const [] : [code];
      case BoardFacetKind.resolution:
        final e = t.providerEntity;
        final code = e is ZenTaoBugEntity
            ? (e.resolution ?? '').toLowerCase()
            : '';
        return code.isEmpty ? const [] : [code];
    }
  }
}

/// Where status [value] (a bug or task column name) sits on its board.
int _statusOrder(String value) {
  for (final c in ZenTaoBugColumn.values) {
    if (c.name == value) return c.order;
  }
  for (final c in ZenTaoTaskColumn.values) {
    if (c.name == value) return c.order;
  }
  return 99;
}

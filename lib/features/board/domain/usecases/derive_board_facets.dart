import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/usecase/usecase.dart';

/// Which board the facets are derived for; selects which dimensions apply.
enum BoardFacetScope { bug, task, gitlabMergeRequest, none }

/// A filterable dimension of a board.
enum BoardFacetKind {
  assignee,
  reviewer,
  severity,
  priority,
  bugType,
  resolution,
}

/// One option within a facet group: its canonical [value] (the exact string/int
/// stored in `FilterState`) and how many scoped tickets carry it.
class BoardFacetOption {
  const BoardFacetOption({required this.value, required this.count});

  final String value;
  final int count;
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

/// Input for [DeriveBoardFacets]: the board-scoped tickets and the board kind.
class BoardFacetsInput {
  const BoardFacetsInput({required this.tickets, required this.scope});

  final List<Ticket> tickets;
  final BoardFacetScope scope;
}

/// Derives the filter facets present in a board's tickets. Assignee stores `''`
/// for unassigned; severity stores the int as a string; priority stores the
/// [Priority] name; bugType/resolution store the lowercased ZenTao code. A group
/// with fewer than two distinct options is dropped (it cannot narrow anything).
class DeriveBoardFacets extends UseCase<BoardFacets, BoardFacetsInput> {
  const DeriveBoardFacets();

  @override
  BoardFacets call(BoardFacetsInput input) {
    if (input.scope == BoardFacetScope.none) return BoardFacets.empty;
    final kinds = switch (input.scope) {
      BoardFacetScope.bug => const [
        BoardFacetKind.assignee,
        BoardFacetKind.severity,
        BoardFacetKind.priority,
        BoardFacetKind.bugType,
        BoardFacetKind.resolution,
      ],
      BoardFacetScope.task => const [
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
      if (counts.length < 2) continue;
      final options =
          counts.entries
              .map((e) => BoardFacetOption(value: e.key, count: e.value))
              .toList()
            ..sort((a, b) => b.count.compareTo(a.count));
      groups.add(BoardFacetGroup(kind: kind, options: options));
    }
    return BoardFacets(groups: groups);
  }

  /// The canonical facet values for [kind] on [t]. Multi-user provider fields
  /// such as GitLab reviewers contribute one count to each user.
  List<String> _valuesFor(BoardFacetKind kind, Ticket t) {
    switch (kind) {
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

# Plan: zentao-filter-redesign phase 2 — DeriveBoardFacets use case

## Context

Add a pure use case that derives the available filter facets (assignee, severity,
priority, bug type, resolution) from the tickets scoped to the current ZenTao
board, with per-option counts, dropping any dimension with < 2 distinct values.
The presentation layer maps the raw values to labels later. Depends on phase 1
(uses `ZenTaoBugEntity`, unchanged `Ticket`).

## Constraints

- NO edits outside the 2 files in this plan (both new).
- Near-miss (do NOT touch): `filter_tickets.dart`, `build_zentao_bug_board.dart`,
  `build_zentao_task_board.dart` — the new use case is standalone.
- The use case is **pure Dart**: no Flutter/Riverpod/l10n imports (rule 1.2/2.1).
  It returns raw values only — no display labels or colors.
- Escape hatch: if `usecase.dart`'s base class signature differs from the
  exemplar below → STOP and report; do not invent a different base.

## Steps

### Step 1: create the use case — `lib/features/board/domain/usecases/derive_board_facets.dart`

- Convention exemplar: `lib/features/board/domain/usecases/build_zentao_bug_board.dart`
  — same file uses `class X extends UseCase<Out, In>` with `Out call(In q)`, plain
  data model classes above it, and imports `../../../../core/usecase/usecase.dart`.
  Follow that structure exactly.
- Create the file with this full content:
  ```dart
  import '../../../../core/domain/entities/provider_entity.dart';
  import '../../../../core/domain/entities/ticket.dart';
  import '../../../../core/usecase/usecase.dart';

  /// Which board the facets are derived for; selects which dimensions apply.
  enum BoardFacetScope { bug, task, none }

  /// A filterable dimension of a ZenTao board.
  enum BoardFacetKind { assignee, severity, priority, bugType, resolution }

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
      final kinds = input.scope == BoardFacetScope.bug
          ? const [
              BoardFacetKind.assignee,
              BoardFacetKind.severity,
              BoardFacetKind.priority,
              BoardFacetKind.bugType,
              BoardFacetKind.resolution,
            ]
          : const [BoardFacetKind.assignee, BoardFacetKind.priority];

      final groups = <BoardFacetGroup>[];
      for (final kind in kinds) {
        final counts = <String, int>{};
        for (final ticket in input.tickets) {
          final value = _valueFor(kind, ticket);
          if (value == null) continue;
          counts[value] = (counts[value] ?? 0) + 1;
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

    /// The canonical facet value for [kind] on [t], or null when the ticket does
    /// not carry that dimension (so it is excluded from the group).
    String? _valueFor(BoardFacetKind kind, Ticket t) {
      switch (kind) {
        case BoardFacetKind.assignee:
          return t.assignee ?? '';
        case BoardFacetKind.severity:
          return t.severity?.toString();
        case BoardFacetKind.priority:
          return t.priority.name;
        case BoardFacetKind.bugType:
          final e = t.providerEntity;
          final code = e is ZenTaoBugEntity
              ? (e.bugType ?? '').toLowerCase()
              : '';
          return code.isEmpty ? null : code;
        case BoardFacetKind.resolution:
          final e = t.providerEntity;
          final code = e is ZenTaoBugEntity
              ? (e.resolution ?? '').toLowerCase()
              : '';
          return code.isEmpty ? null : code;
      }
    }
  }
  ```
- Verify: `fvm dart analyze lib/features/board/domain/usecases/derive_board_facets.dart`
  → expected: "No issues found!", exit 0.

### Step 2: tests — `test/domain/derive_board_facets_test.dart`

- Follow the pattern of `test/domain/board_logic_test.dart` (a local `_bug`
  builder returning a `Ticket`, `group`/`test`/`expect`). Create the file with:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:work_nexus/core/domain/entities/provider_entity.dart';
  import 'package:work_nexus/core/domain/entities/ticket.dart';
  import 'package:work_nexus/core/domain/value_objects/priority.dart';
  import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
  import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
  import 'package:work_nexus/features/board/domain/usecases/derive_board_facets.dart';

  Ticket _bug({
    required String id,
    String? assignee,
    int? severity,
    Priority priority = Priority.medium,
    String? bugType,
    String? resolution,
  }) {
    return Ticket(
      id: id,
      accountId: 'ztB',
      projectId: 'p',
      providerType: ProviderType.zentao,
      externalKey: id,
      externalType: 'Bug',
      title: 't',
      body: '',
      priority: priority,
      status: UnifiedStatus.todo,
      providerStatus: 'active',
      sourceHash: 'h',
      assignee: assignee,
      severity: severity,
      providerEntity: (bugType == null && resolution == null)
          ? null
          : TicketProviderEntity.zentaoBug(
              bugType: bugType,
              resolution: resolution,
            ),
    );
  }

  void main() {
    const derive = DeriveBoardFacets();

    BoardFacetGroup groupOf(BoardFacets f, BoardFacetKind k) =>
        f.groups.firstWhere((g) => g.kind == k);

    test('bug scope derives assignee/severity/priority/type/resolution', () {
      final f = derive(
        BoardFacetsInput(
          scope: BoardFacetScope.bug,
          tickets: [
            _bug(
              id: '1',
              assignee: 'Terry',
              severity: 1,
              priority: Priority.urgent,
              bugType: 'codeerror',
              resolution: 'fixed',
            ),
            _bug(
              id: '2',
              assignee: 'Thanh',
              severity: 3,
              priority: Priority.high,
              bugType: 'config',
            ),
            _bug(
              id: '3',
              assignee: 'Terry',
              severity: 1,
              priority: Priority.high,
              bugType: 'codeerror',
              resolution: 'duplicate',
            ),
          ],
        ),
      );
      expect(f.groups.map((g) => g.kind), [
        BoardFacetKind.assignee,
        BoardFacetKind.severity,
        BoardFacetKind.priority,
        BoardFacetKind.bugType,
        BoardFacetKind.resolution,
      ]);
      expect(groupOf(f, BoardFacetKind.assignee).options.first.value, 'Terry');
      expect(groupOf(f, BoardFacetKind.assignee).options.first.count, 2);
      expect(
        groupOf(f, BoardFacetKind.priority).options.map((o) => o.value).toSet(),
        {'urgent', 'high'},
      );
    });

    test('drops single-value groups', () {
      final f = derive(
        BoardFacetsInput(
          scope: BoardFacetScope.bug,
          tickets: [
            _bug(id: '1', assignee: 'Terry', severity: 1, priority: Priority.high),
            _bug(id: '2', assignee: 'Thanh', severity: 1, priority: Priority.high),
          ],
        ),
      );
      expect(f.groups.map((g) => g.kind), [BoardFacetKind.assignee]);
    });

    test('unassigned uses the empty-string value', () {
      final f = derive(
        BoardFacetsInput(
          scope: BoardFacetScope.bug,
          tickets: [
            _bug(id: '1', assignee: 'Terry', severity: 1),
            _bug(id: '2', severity: 2),
          ],
        ),
      );
      expect(
        groupOf(f, BoardFacetKind.assignee).options.map((o) => o.value),
        contains(''),
      );
    });

    test('task scope limits to assignee + priority', () {
      final f = derive(
        BoardFacetsInput(
          scope: BoardFacetScope.task,
          tickets: [
            _bug(id: '1', assignee: 'A', priority: Priority.urgent),
            _bug(id: '2', assignee: 'B', priority: Priority.low),
          ],
        ),
      );
      expect(f.groups.map((g) => g.kind), [
        BoardFacetKind.assignee,
        BoardFacetKind.priority,
      ]);
    });

    test('none scope yields no groups', () {
      final f = derive(
        const BoardFacetsInput(scope: BoardFacetScope.none, tickets: []),
      );
      expect(f.groups, isEmpty);
    });
  }
  ```
- Verify: `fvm flutter test test/domain/derive_board_facets_test.dart` → expected:
  "All tests passed!", exit 0.

## Final verification

- `fvm dart analyze lib/features/board/domain/usecases/derive_board_facets.dart test/domain/derive_board_facets_test.dart`
  → "No issues found!", exit 0.
- `fvm flutter test test/domain/derive_board_facets_test.dart` → "All tests passed!", exit 0.

## Out of scope

- Do NOT wire the use case into any provider yet (phase 3).
- Do NOT add label/color mapping here — presentation owns that (phase 4).
- Do NOT compute facet counts after applying the chip filters — derive from the
  scoped-but-unfiltered set, exactly as written.

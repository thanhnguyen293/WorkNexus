import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/shared/board/domain/usecases/derive_board_facets.dart';

Ticket _bug({
  required String id,
  String? assignee,
  int? severity,
  Priority priority = Priority.medium,
  String? bugType,
  String? resolution,
  String providerStatus = 'active',
  UnifiedStatus status = UnifiedStatus.todo,
  String? resolvedBy,
  String? openedBy,
  int? confirmed,
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
    status: status,
    providerStatus: providerStatus,
    sourceHash: 'h',
    assignee: assignee,
    severity: severity,
    labels: [if (resolution != null) 'resolution:$resolution'],
    providerEntity:
        (bugType == null &&
            resolution == null &&
            resolvedBy == null &&
            openedBy == null &&
            confirmed == null)
        ? null
        : TicketProviderEntity.zentaoBug(
            bugType: bugType,
            resolution: resolution,
            resolvedBy: resolvedBy,
            openedBy: openedBy,
            confirmed: confirmed,
          ),
  );
}

Ticket _mr({
  required String id,
  List<String> assignees = const [],
  List<String> reviewers = const [],
  Priority priority = Priority.medium,
}) {
  return Ticket(
    id: id,
    accountId: 'gl',
    projectId: 'p',
    providerType: ProviderType.gitlab,
    externalKey: id,
    externalType: 'MergeRequest',
    title: 't',
    body: '',
    priority: priority,
    status: UnifiedStatus.review,
    providerStatus: 'opened',
    sourceHash: 'h',
    assignee: assignees.firstOrNull,
    providerEntity: TicketProviderEntity.gitlabItem(
      assignees: assignees,
      reviewers: reviewers,
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
          _bug(
            id: '1',
            assignee: 'Terry',
            severity: 1,
            priority: Priority.high,
          ),
          _bug(
            id: '2',
            assignee: 'Thanh',
            severity: 1,
            priority: Priority.high,
          ),
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

  test('gitlab merge request scope derives assignee/reviewer/priority', () {
    final f = derive(
      BoardFacetsInput(
        scope: BoardFacetScope.gitlabMergeRequest,
        tickets: [
          _mr(
            id: '1',
            assignees: ['Thanh'],
            reviewers: ['Terry'],
            priority: Priority.urgent,
          ),
          _mr(
            id: '2',
            assignees: ['Terry'],
            reviewers: ['Thanh'],
            priority: Priority.low,
          ),
          _mr(
            id: '3',
            assignees: ['Thanh'],
            reviewers: ['Terry'],
            priority: Priority.low,
          ),
        ],
      ),
    );

    expect(f.groups.map((g) => g.kind), [
      BoardFacetKind.assignee,
      BoardFacetKind.reviewer,
      BoardFacetKind.priority,
    ]);
    expect(groupOf(f, BoardFacetKind.assignee).options.first.value, 'Thanh');
    expect(groupOf(f, BoardFacetKind.reviewer).options.first.value, 'Terry');
  });

  test('bug scope adds status, resolver, reporter and confirmation', () {
    final f = derive(
      BoardFacetsInput(
        scope: BoardFacetScope.bug,
        tickets: [
          _bug(id: '1', openedBy: 'Ryan', confirmed: 1),
          _bug(
            id: '2',
            providerStatus: 'resolved',
            resolution: 'fixed',
            resolvedBy: 'Thanh',
            openedBy: 'Cat',
            confirmed: 1,
          ),
          _bug(
            id: '3',
            providerStatus: 'closed',
            resolvedBy: 'Luci',
            openedBy: 'Ryan',
            confirmed: 0,
          ),
        ],
      ),
    );
    expect(
      f.groups.map((g) => g.kind),
      containsAllInOrder([
        BoardFacetKind.status,
        BoardFacetKind.resolvedBy,
        BoardFacetKind.openedBy,
        BoardFacetKind.confirmed,
      ]),
    );
    // Statuses follow the board's column order, not their counts.
    expect(groupOf(f, BoardFacetKind.status).options.map((o) => o.value), [
      'confirmedToFix',
      'resolvedVerify',
      'closed',
    ]);
    // An unresolved bug has no resolver to count.
    expect(
      groupOf(f, BoardFacetKind.resolvedBy).options.map((o) => o.value),
      unorderedEquals(['Thanh', 'Luci']),
    );
    expect(groupOf(f, BoardFacetKind.openedBy).options.first.value, 'Ryan');
    expect(
      groupOf(f, BoardFacetKind.confirmed).options.map((o) => o.value),
      unorderedEquals(['1', '0']),
    );
  });

  test('none scope yields no groups', () {
    final f = derive(
      const BoardFacetsInput(scope: BoardFacetScope.none, tickets: []),
    );
    expect(f.groups, isEmpty);
  });

  group('with a catalog', () {
    const derive = DeriveBoardFacets();
    BoardFacets facets(List<Ticket> tickets, BoardFacetCatalog catalog) =>
        derive(
          BoardFacetsInput(
            tickets: tickets,
            scope: BoardFacetScope.bug,
            catalog: catalog,
          ),
        );
    BoardFacetGroup group(BoardFacets f, BoardFacetKind kind) =>
        f.groups.firstWhere((g) => g.kind == kind);

    test('lists every choice, with 0 for those no ticket carries', () {
      final f = facets(
        [_bug(id: '1', severity: 2), _bug(id: '2', severity: 2)],
        const BoardFacetCatalog({
          BoardFacetKind.severity: [
            BoardFacetChoice('1'),
            BoardFacetChoice('2'),
            BoardFacetChoice('3'),
          ],
        }),
      );
      final severity = group(f, BoardFacetKind.severity);
      expect(severity.options.map((o) => o.value), ['1', '2', '3']);
      expect(severity.options.map((o) => o.count), [0, 2, 0]);
    });

    test('keeps a dimension whose tickets all carry one value', () {
      final f = facets(
        [_bug(id: '1', assignee: 'thanh')],
        const BoardFacetCatalog({
          BoardFacetKind.assignee: [
            BoardFacetChoice('thanh', label: 'Thanh Nguyen'),
            BoardFacetChoice('an', label: 'An Le'),
          ],
        }),
      );
      final assignee = group(f, BoardFacetKind.assignee);
      expect(assignee.options.map((o) => o.label), ['Thanh Nguyen', 'An Le']);
      expect(assignee.options.first.count, 1);
    });

    test('adds what the tickets carry that the catalog lacks, after it', () {
      final f = facets(
        [_bug(id: '1', assignee: 'guest'), _bug(id: '2', assignee: 'thanh')],
        const BoardFacetCatalog({
          BoardFacetKind.assignee: [BoardFacetChoice('thanh')],
        }),
      );
      expect(group(f, BoardFacetKind.assignee).options.map((o) => o.value), [
        'thanh',
        'guest',
      ]);
    });

    test('leaves a dimension it does not name to the tickets', () {
      final f = facets(
        [_bug(id: '1', severity: 1)],
        const BoardFacetCatalog({
          BoardFacetKind.assignee: [BoardFacetChoice('thanh')],
        }),
      );
      // One severity cannot narrow anything, and the catalog adds none.
      expect(f.groups.any((g) => g.kind == BoardFacetKind.severity), isFalse);
    });
  });
}

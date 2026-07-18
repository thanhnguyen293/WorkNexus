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

  test('none scope yields no groups', () {
    final f = derive(
      const BoardFacetsInput(scope: BoardFacetScope.none, tickets: []),
    );
    expect(f.groups, isEmpty);
  });
}

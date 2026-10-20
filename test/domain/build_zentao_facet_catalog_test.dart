import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/shared/board/domain/usecases/derive_board_facets.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/build_zentao_facet_catalog.dart';

/// The ZenTao boards' catalog: every fixed choice at once, and the people of
/// the product or execution once they are known.
void main() {
  const build = BuildZenTaoFacetCatalog();
  const members = [
    ProviderUser(account: 'thanh', displayName: 'Thanh Nguyen'),
    ProviderUser(account: 'an', displayName: 'An Le'),
  ];

  List<String> values(BoardFacetCatalog c, BoardFacetKind kind) => [
    for (final choice in c.choices[kind] ?? const <BoardFacetChoice>[])
      choice.value,
  ];

  test('the bug board lists every fixed choice', () {
    final c = build(const ZenTaoFacetCatalogInput(bugs: true, members: []));
    expect(values(c, BoardFacetKind.severity), ['1', '2', '3', '4']);
    expect(values(c, BoardFacetKind.confirmed), ['1', '0']);
    expect(values(c, BoardFacetKind.bugType), contains('codeerror'));
    expect(values(c, BoardFacetKind.resolution), contains('fixed'));
    expect(values(c, BoardFacetKind.status).first, 'newUnconfirmed');
  });

  test('without members the people are left to the tickets', () {
    final c = build(const ZenTaoFacetCatalogInput(bugs: true, members: []));
    expect(c.choices.containsKey(BoardFacetKind.assignee), isFalse);
    expect(c.choices.containsKey(BoardFacetKind.openedBy), isFalse);
  });

  test('assignees are logins named by the person, then Unassigned', () {
    final c = build(
      const ZenTaoFacetCatalogInput(bugs: true, members: members),
    );
    final assignees = c.choices[BoardFacetKind.assignee]!;
    // In name order.
    expect(assignees.map((a) => a.value), ['an', 'thanh', '']);
    expect(assignees.first.label, 'An Le');
  });

  test('opener and resolver match on the name the person goes by', () {
    final c = build(
      const ZenTaoFacetCatalogInput(bugs: true, members: members),
    );
    expect(values(c, BoardFacetKind.openedBy), ['An Le', 'Thanh Nguyen']);
    expect(values(c, BoardFacetKind.resolvedBy), ['An Le', 'Thanh Nguyen']);
  });

  test('the task board has its own statuses, assignees and priorities', () {
    final c = build(
      const ZenTaoFacetCatalogInput(bugs: false, members: members),
    );
    expect(c.choices.keys, {
      BoardFacetKind.status,
      BoardFacetKind.assignee,
      BoardFacetKind.priority,
    });
    expect(values(c, BoardFacetKind.status).first, 'notStarted');
  });
}

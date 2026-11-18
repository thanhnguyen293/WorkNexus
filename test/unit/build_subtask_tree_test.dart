import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/build_subtask_tree.dart';

TicketSubtask _sub(String id, {String? parent}) => TicketSubtask(
  id: id,
  title: 'Task $id',
  status: UnifiedStatus.todo,
  parentId: parent,
);

List<String> _ids(List<SubtaskNode> nodes) => [
  for (final n in nodes) n.subtask.id,
];

void main() {
  const build = BuildSubtaskTree();

  test('nests grandchildren under their parent, not beside it', () {
    final tree = build(
      SubtaskTreeInput(
        parentId: '1',
        subtasks: [
          _sub('10', parent: '1'),
          _sub('11', parent: '1'),
          _sub('20', parent: '10'),
          _sub('21', parent: '10'),
          _sub('30', parent: '20'),
          _sub('22', parent: '11'),
        ],
      ),
    );

    expect(_ids(tree.roots), ['10', '11']);
    expect(_ids(tree.roots[0].children), ['20', '21']);
    expect(_ids(tree.roots[0].children[0].children), ['30']);
    expect(_ids(tree.roots[1].children), ['22']);
    expect(tree.total, 6);
    expect(tree.isNested, isTrue);
  });

  test('a flat list stays flat and keeps its order', () {
    final tree = build(
      SubtaskTreeInput(
        parentId: '1',
        subtasks: [
          _sub('12', parent: '1'),
          _sub('10', parent: '1'),
        ],
      ),
    );

    expect(_ids(tree.roots), ['12', '10']);
    expect(tree.isNested, isFalse);
  });

  test('subtasks with an unknown or missing parent are direct subtasks', () {
    final tree = build(
      SubtaskTreeInput(
        parentId: '1',
        subtasks: [
          _sub('10'),
          _sub('11', parent: '99'),
        ],
      ),
    );

    expect(_ids(tree.roots), ['10', '11']);
  });

  test('a parent loop surfaces its members instead of dropping them', () {
    final tree = build(
      SubtaskTreeInput(
        parentId: '1',
        subtasks: [
          _sub('10', parent: '1'),
          _sub('20', parent: '21'),
          _sub('21', parent: '20'),
          _sub('30', parent: '30'),
        ],
      ),
    );

    expect(_ids(tree.roots), ['10', '30', '20']);
    expect(_ids(tree.roots[2].children), ['21']);
    expect(tree.total, 4);
  });
}

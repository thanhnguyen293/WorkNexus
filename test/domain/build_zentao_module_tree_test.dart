import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/build_zentao_module_tree.dart';

Ticket _bug(String id, String module) => Ticket(
  id: id,
  accountId: 'zt',
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: id,
  title: 'Bug $id',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
  providerEntity: TicketProviderEntity.zentaoBug(module: module),
);

/// The bug board's module tree: named and indented by path, counted from the
/// board's bugs, empty modules hidden on request.
void main() {
  const build = BuildZenTaoModuleTree();
  const paths = {
    '0': '',
    '1': 'Live stream',
    '2': 'Live stream/Share',
    '3': 'Feed',
    '4': 'Location',
  };
  final bugs = [_bug('a', '2'), _bug('b', '2'), _bug('c', '3'), _bug('d', '0')];

  List<String> names(ZenTaoModuleTree tree) => [
    for (final n in tree.nodes) '${'  ' * n.depth}${n.name}:${n.count}',
  ];

  test('names each module by its last path part, indented and counted', () {
    final tree = build(ZenTaoModuleTreeInput(paths: paths, bugs: bugs));
    expect(names(tree), ['Live stream:0', '  Share:2', 'Feed:1', 'Location:0']);
    expect(tree.total, 4);
  });

  test('hiding empty modules keeps parents of busy sub-modules', () {
    expect(
      names(
        build(ZenTaoModuleTreeInput(paths: paths, bugs: bugs, hideEmpty: true)),
      ),
      ['Live stream:0', '  Share:2', 'Feed:1'],
    );
  });

  test('the picked module stays even when empty', () {
    expect(
      names(
        build(
          ZenTaoModuleTreeInput(
            paths: paths,
            bugs: bugs,
            hideEmpty: true,
            selected: '4',
          ),
        ),
      ),
      ['Live stream:0', '  Share:2', 'Feed:1', 'Location:0'],
    );
  });
}

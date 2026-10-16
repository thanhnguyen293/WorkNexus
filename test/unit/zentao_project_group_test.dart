import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/tools/zentao/data/models/zentao_models.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_project_group.dart';

ProviderProject _p(String id, String name, [String? programId, String? n]) =>
    ProviderProject(
      id: id,
      name: name,
      accountId: 'zt',
      programId: programId,
      programName: n,
    );

void main() {
  group('ZenTaoProject.fromJson', () {
    test('a project\'s program is its parent', () {
      final p = ZenTaoProject.fromJson(const {
        'id': 7,
        'name': 'Wallet',
        'parent': 3,
        'path': ',3,7,',
      });
      expect((p.programId, p.programName), ('3', null));
    });

    test('`program` stands in where there is no parent; 0 is none', () {
      expect(
        ZenTaoProject.fromJson(const {'id': 7, 'program': '5'}).programId,
        '5',
      );
      expect(
        ZenTaoProject.fromJson(const {'id': 7, 'parent': 0}).programId,
        isNull,
      );
    });
  });

  test('/programs names programs, sub-programs included', () {
    final res = ZenTaoProgramsResponse.fromJson(const {
      'total': 2,
      'programs': [
        {
          'id': 3,
          'name': 'VN Program',
          'children': [
            {'id': 4, 'name': 'Wallet line'},
          ],
        },
      ],
    });
    expect(res.names, {'3': 'VN Program', '4': 'Wallet line'});
  });

  group('ZenTaoProjectTree', () {
    test('groups by program in ZenTao\'s order, the rest after', () {
      final tree = ZenTaoProjectTree.of([
        _p('1', 'VN_Wallet', '3', 'Mobile'),
        _p('2', 'HK_Chat', '9', 'Asia'),
        _p('3', 'VN_Chat', '3', 'Mobile'),
        _p('4', 'HK_Wallet'),
        _p('5', 'Code Security Review'),
      ]);

      expect(tree.groups.map((g) => (g.id, g.name)), [
        ('program:3', 'Mobile'),
        ('program:9', 'Asia'),
      ]);
      // Inside a folder: ZenTao's order. The loose ones: by name.
      expect(tree.groups.first.projects.map((p) => p.id), ['1', '3']);
      expect(tree.ungrouped.map((p) => p.name), [
        'Code Security Review',
        'HK_Wallet',
      ]);
    });

    test('no folder is made up from a name prefix', () {
      final tree = ZenTaoProjectTree.of([
        _p('1', 'VN_IM_Chat'),
        _p('2', 'HK_Wallet'),
        _p('3', 'VN_Wallet'),
      ]);

      expect(tree.groups, isEmpty);
      // Flat, sorted by name.
      expect(tree.ungrouped.map((p) => p.name), [
        'HK_Wallet',
        'VN_IM_Chat',
        'VN_Wallet',
      ]);
    });

    test('programs that could not be named leave the list flat', () {
      final tree = ZenTaoProjectTree.of([_p('2', 'B', '3'), _p('1', 'A', '3')]);

      expect(tree.groups, isEmpty);
      expect(tree.ungrouped.map((p) => p.name), ['A', 'B']);
    });
  });
}

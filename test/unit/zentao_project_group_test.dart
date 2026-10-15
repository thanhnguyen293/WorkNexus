import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_project_group.dart';

void main() {
  group('ZenTaoProjectGroup.group', () {
    test('groups projects by prefix like VN_ and HK_ into Project Sets', () {
      const projects = [
        ProviderProject(id: '1', name: 'VN_IM_Chat', accountId: 'acc1'),
        ProviderProject(id: '2', name: 'VN_Wallet', accountId: 'acc1'),
        ProviderProject(
          id: '3',
          name: 'HK_TBChat_Remastered',
          accountId: 'acc1',
        ),
        ProviderProject(id: '4', name: 'HK_Wallet', accountId: 'acc1'),
        ProviderProject(id: '5', name: 'HK_Cloud_Storage', accountId: 'acc1'),
      ];

      final groups = ZenTaoProjectGroup.group(projects);

      expect(groups.length, equals(2));
      expect(groups[0].name, equals('HK'));
      expect(groups[0].projects.map((p) => p.name).toList(), [
        'HK_Cloud_Storage',
        'HK_TBChat_Remastered',
        'HK_Wallet',
      ]);

      expect(groups[1].name, equals('VN'));
      expect(groups[1].projects.map((p) => p.name).toList(), [
        'VN_IM_Chat',
        'VN_Wallet',
      ]);
    });

    test('prioritizes programName when provided over name prefix', () {
      const projects = [
        ProviderProject(
          id: '1',
          name: 'VN_IM_Chat',
          accountId: 'acc1',
          programId: '10',
          programName: 'Mobile Platform',
        ),
        ProviderProject(
          id: '2',
          name: 'HK_Wallet',
          accountId: 'acc1',
          programId: '10',
          programName: 'Mobile Platform',
        ),
        ProviderProject(id: '3', name: 'VN_Wallet', accountId: 'acc1'),
      ];

      final groups = ZenTaoProjectGroup.group(projects);

      expect(groups.length, equals(2));
      expect(groups[0].name, equals('Mobile Platform'));
      expect(groups[0].projects.length, equals(2));
      expect(groups[1].name, equals('VN'));
      expect(groups[1].projects.length, equals(1));
    });

    test('places projects without recognized prefix into Other group', () {
      const projects = [
        ProviderProject(id: '1', name: 'VN_App', accountId: 'acc1'),
        ProviderProject(id: '2', name: 'StandaloneProject', accountId: 'acc1'),
      ];

      final groups = ZenTaoProjectGroup.group(projects);

      expect(groups.length, equals(2));
      expect(groups[0].name, equals('VN'));
      expect(groups[1].name, equals('Other'));
      expect(groups[1].projects.single.name, equals('StandaloneProject'));
    });

    test('returns empty list when project list is empty', () {
      final groups = ZenTaoProjectGroup.group(const []);
      expect(groups, isEmpty);
    });
  });
}

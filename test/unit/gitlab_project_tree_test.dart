import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/tools/gitlab/domain/entities/gitlab_project_tree.dart';

void main() {
  group('GitLabProjectTree.build', () {
    test(
      'builds multi-level hierarchy matching GitLab group / subgroup / project',
      () {
        const projects = [
          ProviderProject(
            id: '1',
            name: 'icom / Server / storage',
            accountId: 'acc1',
          ),
          ProviderProject(
            id: '2',
            name: 'icom / Server / Subscription',
            accountId: 'acc1',
          ),
          ProviderProject(
            id: '3',
            name: 'icom / Server / payment',
            accountId: 'acc1',
          ),
          ProviderProject(
            id: '4',
            name: 'icom / Server / socialfi / post',
            accountId: 'acc1',
          ),
          ProviderProject(
            id: '5',
            name: 'icom / Server / socialfi / feed',
            accountId: 'acc1',
          ),
          ProviderProject(
            id: '6',
            name: 'other-group / tool',
            accountId: 'acc1',
          ),
          ProviderProject(
            id: '7',
            name: 'standalone-project',
            accountId: 'acc1',
          ),
        ];

        final tree = GitLabProjectTree.build(projects);

        // Root groups
        expect(tree.rootGroups.length, equals(2));
        expect(tree.rootGroups[0].name, equals('icom'));
        expect(tree.rootGroups[0].fullPath, equals('icom'));
        expect(tree.rootGroups[1].name, equals('other-group'));

        // Root projects (no slash)
        expect(tree.rootProjects.length, equals(1));
        expect(tree.rootProjects[0].name, equals('standalone-project'));

        // Subgroup under icom
        final icom = tree.rootGroups[0];
        expect(icom.subgroups.length, equals(1));
        final server = icom.subgroups[0];
        expect(server.name, equals('Server'));
        expect(server.fullPath, equals('icom/Server'));

        // Projects directly under icom/Server
        expect(server.projects.map(gitlabShortProjectName).toList(), [
          'payment',
          'storage',
          'Subscription',
        ]);

        // Nested subgroup under icom/Server: socialfi
        expect(server.subgroups.length, equals(1));
        final socialfi = server.subgroups[0];
        expect(socialfi.name, equals('socialfi'));
        expect(socialfi.fullPath, equals('icom/Server/socialfi'));
        expect(socialfi.projects.map(gitlabShortProjectName).toList(), [
          'feed',
          'post',
        ]);

        // Total count aggregation
        expect(icom.totalProjectCount, equals(5));
        expect(server.totalProjectCount, equals(5));
        expect(socialfi.totalProjectCount, equals(2));
      },
    );

    test('returns empty tree when projects list is empty', () {
      final tree = GitLabProjectTree.build(const []);
      expect(tree.rootGroups, isEmpty);
      expect(tree.rootProjects, isEmpty);
    });
  });
}

import '../../../../core/domain/adapters/provider_adapter.dart';

/// Helper to get the short project name for a GitLab project.
/// E.g. `icom / Server / storage` -> `storage`.
String gitlabShortProjectName(ProviderProject project) {
  final parts = project.name.split(RegExp(r'\s*/\s*'));
  return parts.isNotEmpty ? parts.last.trim() : project.name;
}

/// A node in the GitLab group/subgroup tree hierarchy.
class GitLabGroupNode {
  const GitLabGroupNode({
    required this.name,
    required this.fullPath,
    this.subgroups = const [],
    this.projects = const [],
  });

  /// Name of this group or subgroup (e.g. `icom`, `Server`, `socialfi`).
  final String name;

  /// Full path of this group (e.g. `icom`, `icom/Server`, `icom/Server/socialfi`).
  final String fullPath;

  /// Child subgroups.
  final List<GitLabGroupNode> subgroups;

  /// Child projects directly under this group/subgroup.
  final List<ProviderProject> projects;

  /// Recursively counts all projects inside this group and all its subgroups.
  int get totalProjectCount =>
      projects.length +
      subgroups.fold<int>(0, (sum, g) => sum + g.totalProjectCount);
}

/// The entire hierarchical project tree for a GitLab account.
class GitLabProjectTree {
  const GitLabProjectTree({
    this.rootGroups = const [],
    this.rootProjects = const [],
  });

  final List<GitLabGroupNode> rootGroups;
  final List<ProviderProject> rootProjects;

  /// Builds a [GitLabProjectTree] from a list of [ProviderProject]s.
  static GitLabProjectTree build(List<ProviderProject> projects) {
    if (projects.isEmpty) {
      return const GitLabProjectTree();
    }

    final rootBuilder = _BuilderGroup('', '');
    final rootProjects = <ProviderProject>[];

    for (final p in projects) {
      final parts = p.name
          .split(RegExp(r'\s*/\s*'))
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.length <= 1) {
        rootProjects.add(p);
      } else {
        _BuilderGroup current = rootBuilder;
        final groupTokens = parts.sublist(0, parts.length - 1);
        final pathBuffer = StringBuffer();

        for (var i = 0; i < groupTokens.length; i++) {
          final token = groupTokens[i];
          if (i > 0) pathBuffer.write('/');
          pathBuffer.write(token);
          final pathSoFar = pathBuffer.toString();

          current = current.subgroups.putIfAbsent(
            token,
            () => _BuilderGroup(token, pathSoFar),
          );
        }

        current.projects.add(p);
      }
    }

    final sortedRootProjects = rootProjects.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final sortedRootGroups =
        rootBuilder.subgroups.values.map((b) => b.toNode()).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return GitLabProjectTree(
      rootGroups: sortedRootGroups,
      rootProjects: sortedRootProjects,
    );
  }
}

class _BuilderGroup {
  _BuilderGroup(this.name, this.fullPath);

  final String name;
  final String fullPath;
  final Map<String, _BuilderGroup> subgroups = {};
  final List<ProviderProject> projects = [];

  GitLabGroupNode toNode() {
    final sortedSubgroups = subgroups.values.map((s) => s.toNode()).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final sortedProjects = projects.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return GitLabGroupNode(
      name: name,
      fullPath: fullPath,
      subgroups: sortedSubgroups,
      projects: sortedProjects,
    );
  }
}

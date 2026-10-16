import '../../../../core/domain/adapters/provider_adapter.dart';

/// A program's folder of ZenTao projects — ZenTao's own grouping (a
/// project's program is its parent), never one made up from names.
class ZenTaoProjectGroup {
  const ZenTaoProjectGroup({
    required this.id,
    required this.name,
    required this.projects,
  });

  /// `program:<id>`.
  final String id;

  final String name;

  final List<ProviderProject> projects;
}

/// The projects as ZenTao groups them: [groups] by program, in ZenTao's
/// order, then the projects in no (named) program ([ungrouped]).
class ZenTaoProjectTree {
  const ZenTaoProjectTree({required this.groups, required this.ungrouped});

  final List<ZenTaoProjectGroup> groups;
  final List<ProviderProject> ungrouped;

  /// Builds the tree from [projects] in the order ZenTao listed them. When
  /// no program is known — an older server, or `/programs` unavailable —
  /// they stay one flat list, sorted by name.
  factory ZenTaoProjectTree.of(List<ProviderProject> projects) {
    bool hasProgram(ProviderProject p) =>
        p.programId != null && (p.programName?.isNotEmpty ?? false);
    if (!projects.any(hasProgram)) {
      return ZenTaoProjectTree(
        groups: const [],
        ungrouped: [
          ...projects,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );
    }
    final groups = <String, ({String name, List<ProviderProject> list})>{};
    final ungrouped = <ProviderProject>[];
    for (final p in projects) {
      if ((p.programId, p.programName) case (
        final id?,
        final name?,
      ) when name.isNotEmpty) {
        groups
            .putIfAbsent('program:$id', () => (name: name, list: []))
            .list
            .add(p);
      } else {
        ungrouped.add(p);
      }
    }
    return ZenTaoProjectTree(
      groups: [
        for (final MapEntry(:key, :value) in groups.entries)
          ZenTaoProjectGroup(id: key, name: value.name, projects: value.list),
      ],
      ungrouped: ungrouped,
    );
  }
}

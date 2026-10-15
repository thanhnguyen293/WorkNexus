import '../../../../core/domain/adapters/provider_adapter.dart';

/// A logical or API-backed group of ZenTao projects (Project Set / Program).
class ZenTaoProjectGroup {
  const ZenTaoProjectGroup({
    required this.id,
    required this.name,
    required this.projects,
  });

  /// Group identifier (e.g. `prog:12`, `pfx:VN`, or `other`).
  final String id;

  /// Display name of the Project Set / Program (e.g. `VN`, `HK`, `Mobile Platform`).
  final String name;

  /// Projects belonging to this group.
  final List<ProviderProject> projects;

  /// Groups a list of [ProviderProject]s by Program or common name prefix.
  static List<ZenTaoProjectGroup> group(
    List<ProviderProject> projects, {
    String? prioritizeZone,
  }) {
    if (projects.isEmpty) return const [];

    final groups =
        <String, ({String id, String name, List<ProviderProject> list})>{};
    final fallbackList = <ProviderProject>[];

    final prefixRegex = RegExp(r'^([A-Za-z0-9]+)[_\-\s/]');

    for (final p in projects) {
      final progName = p.programName?.trim();
      if (progName != null && progName.isNotEmpty) {
        final key = 'prog_${p.programId ?? progName}';
        final existing = groups[key];
        if (existing == null) {
          groups[key] = (id: key, name: progName, list: [p]);
        } else {
          existing.list.add(p);
        }
      } else {
        final match = prefixRegex.firstMatch(p.name);
        if (match != null) {
          final prefix = match.group(1)!.toUpperCase();
          final key = 'pfx_$prefix';
          final existing = groups[key];
          if (existing == null) {
            groups[key] = (id: key, name: prefix, list: [p]);
          } else {
            existing.list.add(p);
          }
        } else {
          fallbackList.add(p);
        }
      }
    }

    final result = <ZenTaoProjectGroup>[];
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final nameA = groups[a]!.name;
        final nameB = groups[b]!.name;
        if (prioritizeZone != null && prioritizeZone.trim().isNotEmpty) {
          final zone = prioritizeZone.trim().toUpperCase();
          final aMatch =
              nameA.toUpperCase() == zone ||
              nameA.toUpperCase().startsWith('${zone}_') ||
              nameA.toUpperCase().startsWith('$zone-');
          final bMatch =
              nameB.toUpperCase() == zone ||
              nameB.toUpperCase().startsWith('${zone}_') ||
              nameB.toUpperCase().startsWith('$zone-');
          if (aMatch != bMatch) {
            return aMatch ? -1 : 1;
          }
        }
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

    for (final k in sortedKeys) {
      final g = groups[k]!;
      g.list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      result.add(ZenTaoProjectGroup(id: g.id, name: g.name, projects: g.list));
    }

    if (fallbackList.isNotEmpty) {
      fallbackList.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      result.add(
        ZenTaoProjectGroup(id: 'other', name: 'Other', projects: fallbackList),
      );
    }

    return result;
  }
}

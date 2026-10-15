import '../../../../core/domain/adapters/provider_adapter.dart';

/// A logical group of ZenTao products based on department prefix or naming.
class ZenTaoProductGroup {
  const ZenTaoProductGroup({
    required this.id,
    required this.name,
    required this.products,
  });

  /// Group identifier (e.g. `pfx:VN`, `pfx:HK`, or `other`).
  final String id;

  /// Display name of the product group (e.g. `VN`, `HK`, `Code`).
  final String name;

  /// Products belonging to this group.
  final List<ProviderProduct> products;

  /// Groups a list of [ProviderProduct]s by common name prefix, prioritizing [prioritizeZone].
  static List<ZenTaoProductGroup> group(
    List<ProviderProduct> products, {
    String? prioritizeZone,
  }) {
    if (products.isEmpty) return const [];

    final groups =
        <String, ({String id, String name, List<ProviderProduct> list})>{};
    final fallbackList = <ProviderProduct>[];

    final prefixRegex = RegExp(r'^([A-Za-z0-9]+)[_\-\s/]');

    for (final p in products) {
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

    final result = <ZenTaoProductGroup>[];
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
      result.add(ZenTaoProductGroup(id: g.id, name: g.name, products: g.list));
    }

    if (fallbackList.isNotEmpty) {
      fallbackList.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      result.add(
        ZenTaoProductGroup(id: 'other', name: 'Other', products: fallbackList),
      );
    }

    return result;
  }
}

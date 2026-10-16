import '../../../../core/debug/app_talker.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/network/api_paging.dart';
import '../datasources/zentao_client.dart';

/// The containers an account's sidebar lists — products and projects — with
/// ZenTao's own grouping: a product's program and line, a project's program.
/// Never a made-up one: when the grouping is not to be had, the lists come
/// back without it and the sidebar shows them flat.
class ZenTaoSourceLists {
  const ZenTaoSourceLists(this._client, {required this.accountId});

  final ZenTaoClient _client;
  final String accountId;

  /// Every product, filed under program and line from ZenTao's merged tree;
  /// an older server without it (or failing on it) gets the plain list.
  Future<List<ProviderProduct>> products() async {
    try {
      return await _allProducts(merged: true);
    } on Object catch (e) {
      appTalker.warning('ZenTao product tree unavailable: $e');
      return _allProducts(merged: false);
    }
  }

  /// Every product, page by page (the tree may be paged like the list).
  Future<List<ProviderProduct>> _allProducts({required bool merged}) async {
    const limit = kDefaultApiPageLimit;
    final out = <ProviderProduct>[];
    final seen = <String>{};
    var total = 0;
    for (var page = 1; page <= 50; page++) {
      final res = await _client.products(
        page: page,
        limit: limit,
        merged: merged,
      );
      if (res.total > 0) total = res.total;
      var added = 0;
      for (final product in res.products) {
        if (product.id.isEmpty || !seen.add(product.id)) continue;
        out.add(
          ProviderProduct(
            id: product.id,
            name: product.name.isEmpty ? product.id : product.name,
            accountId: accountId,
            programId: product.programId,
            programName: product.programName,
            lineId: product.lineId,
            lineName: product.lineName,
          ),
        );
        added++;
      }
      if (added == 0) break;
      if (total > 0 && out.length >= total) break;
    }
    return out;
  }

  /// Every project, each with its program (its `parent`), named from
  /// `/programs`.
  Future<List<ProviderProject>> projects() async {
    const limit = kDefaultApiPageLimit;
    final out = <ProviderProject>[];
    final seen = <String>{};
    var total = 0;
    for (var page = 1; page <= 50; page++) {
      final res = await _client.projects(page: page, limit: limit);
      if (res.total > 0) total = res.total;
      var added = 0;
      for (final project in res.projects) {
        if (project.id.isEmpty || !seen.add(project.id)) continue;
        out.add(
          ProviderProject(
            id: project.id,
            name: project.name.isEmpty ? project.id : project.name,
            accountId: accountId,
            programId: project.programId,
            programName: project.programName,
          ),
        );
        added++;
      }
      if (added == 0) break;
      if (total > 0 && out.length >= total) break;
    }
    return _withProgramNames(out);
  }

  /// Names [projects]' programs from `/programs`. Without it (an older
  /// server, or the call failing) they stay unnamed, and the sidebar shows
  /// the projects flat.
  Future<List<ProviderProject>> _withProgramNames(
    List<ProviderProject> projects,
  ) async {
    if (!projects.any((p) => p.programId != null && p.programName == null)) {
      return projects;
    }
    final names = <String, String>{};
    try {
      for (var page = 1; page <= 20; page++) {
        final res = await _client.programs(
          page: page,
          limit: kDefaultApiPageLimit,
        );
        final before = names.length;
        for (final MapEntry(:key, :value) in res.names.entries) {
          names.putIfAbsent(key, () => value);
        }
        if (names.length == before) break;
        if (res.total > 0 && names.length >= res.total) break;
      }
    } on Object catch (e) {
      appTalker.warning('ZenTao programs unavailable: $e');
    }
    return [
      for (final p in projects)
        ProviderProject(
          id: p.id,
          name: p.name,
          accountId: p.accountId,
          programId: p.programId,
          programName: p.programName ?? names[p.programId],
        ),
    ];
  }
}

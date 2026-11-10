import '../entities/zentao_doc_lib.dart';

/// Narrows [libs] to those whose name contains [query] (case-insensitive,
/// surrounding spaces ignored), keeping the server's order. An empty query
/// keeps every library.
class FilterZenTaoDocLibs {
  const FilterZenTaoDocLibs();

  List<ZenTaoDocLib> call(List<ZenTaoDocLib> libs, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return libs;
    return [
      for (final lib in libs)
        if (lib.name.toLowerCase().contains(q)) lib,
    ];
  }
}

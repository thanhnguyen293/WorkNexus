import 'package:json_annotation/json_annotation.dart';

part 'zentao_models.g.dart';
part 'zentao_models_tickets.dart';
part 'zentao_models_accounts.dart';
part 'zentao_models_catalog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// JSON DTOs for the ZenTao REST v1 API (deserialize-only). ZenTao's payloads are
// loosely typed — numbers arrive as ints or strings, `assignedTo`/`actor` as a
// bare string or an `{account, realname}` object, and `actions` as a list or an
// id-keyed map — so union-shaped fields stay `Object?` (read leniently via the
// helpers in `zentao_normalize.dart`) and numeric fields go through [zentaoInt].
// These DTOs never leave the data layer (rule 3.3): the adapter maps them to
// domain entities at the boundary.
// ─────────────────────────────────────────────────────────────────────────────

/// Lenient int parse: accepts `int`, `num`, or numeric `String` (ZenTao mixes).
int? zentaoInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// ZenTao returns `actions` as a JSON array or an id-keyed object; normalize
/// both to a chronologically-sorted list of [ZenTaoAction].
List<ZenTaoAction> zentaoActions(Object? raw) {
  final List<Object?> values;
  if (raw is List) {
    values = raw;
  } else if (raw is Map) {
    values = raw.values.toList()
      ..sort((a, b) {
        final ai = a is Map ? (zentaoInt(a['id']) ?? 0) : 0;
        final bi = b is Map ? (zentaoInt(b['id']) ?? 0) : 0;
        return ai.compareTo(bi);
      });
  } else {
    return const [];
  }
  return [
    for (final e in values)
      if (e is Map) ZenTaoAction.fromJson(Map<String, dynamic>.from(e)),
  ];
}

/// ZenTao returns `files` as an id-keyed object (`{ "7931": {...}, ... }`);
/// normalize it to a list, ordered by ascending id (upload order).
List<ZenTaoFile> zentaoFiles(Object? raw) {
  if (raw is! Map) return const [];
  final entries =
      <Map<String, dynamic>>[
        for (final v in raw.values)
          if (v is Map) Map<String, dynamic>.from(v),
      ]..sort((a, b) {
        final ai = zentaoInt(a['id']) ?? 0;
        final bi = zentaoInt(b['id']) ?? 0;
        return ai.compareTo(bi);
      });
  return [for (final e in entries) ZenTaoFile.fromJson(e)];
}

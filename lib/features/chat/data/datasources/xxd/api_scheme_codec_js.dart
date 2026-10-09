part of 'api_scheme_codec.dart';

// ---- JS semantics helpers --------------------------------------------------

Object? _default(Map<String, Object?> rt) =>
    rt.containsKey('default') ? rt['default'] : _absent;

/// `undefined` serialises as `null` inside JSON arrays.
Object? _jsonValue(Object? v) => identical(v, _absent) ? null : v;

bool _isJsObject(Object? v) => v == null || v is Map || v is List;

bool _truthy(Object? v) =>
    v != null &&
    !identical(v, _absent) &&
    v != false &&
    v != 0 &&
    v != '' &&
    !(v is double && v.isNaN);

/// JS `===` for the primitives a scheme map can hold.
bool _strictEquals(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (identical(a, _absent) || identical(b, _absent)) {
    return identical(a, b);
  }
  return a.runtimeType == b.runtimeType && a == b;
}

/// JS `Ce`: deep equality used to detect props still at their default.
bool _jsEquals(Object? a, Object? b) {
  if (identical(a, b) || _strictEquals(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; ++i) {
      if (!_jsEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if ((a is Map || a is List) && (b is Map || b is List)) {
    final ak = _jsKeys(a!);
    final bk = _jsKeys(b!);
    if (ak.length != bk.length) return false;
    for (final k in ak) {
      if (!_jsEquals(_jsGet(a, k), _jsGet(b, k))) return false;
    }
    return true;
  }
  return false;
}

List<String> _jsKeys(Object o) => o is Map
    ? [for (final k in o.keys) '$k']
    : [for (var i = 0; i < (o as List).length; ++i) '$i'];

Object? _jsGet(Object o, String key) {
  if (o is Map) return o.containsKey(key) ? o[key] : _absent;
  final i = int.tryParse(key);
  final list = o as List;
  return i != null && i >= 0 && i < list.length ? list[i] : _absent;
}

String _jsToString(Object? v) {
  if (v == null) return 'null';
  if (v is double) {
    if (v.isNaN) return 'NaN';
    if (v.isInfinite) return v > 0 ? 'Infinity' : '-Infinity';
    if (v == v.truncateToDouble() && v.abs() < 1e21) {
      return v.toInt().toString();
    }
    return v.toString();
  }
  if (v is List) {
    return v.map((e) => e == null ? '' : _jsToString(e)).join(',');
  }
  if (v is Map) return '[object Object]';
  return '$v';
}

/// JS `Number.parseFloat`: longest numeric prefix. Integral results come
/// back as `int` so they match `jsonDecode` output. JS yields NaN when there
/// is no number; that serialises as `null`, and `jsonEncode` cannot take NaN,
/// so null is returned instead.
num? _parseFloat(String s) {
  final m = _floatPrefix.firstMatch(s);
  if (m == null) return null;
  final d = double.parse(m.group(1)!);
  return d.isFinite && d == d.truncateToDouble() && d.abs() < 9007199254740992
      ? d.toInt()
      : d;
}

final _canonicalIndex = RegExp(r'^(0|[1-9]\d*)$');
final _floatPrefix = RegExp(
  r'^\s*([+-]?(?:Infinity|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?))',
);

const _primitiveTypes = {
  'any',
  'string',
  'number',
  'boolean',
  'object',
  'array',
};

const Map<String, Object?> _builtInSchemes = {
  'string': {'type': 'string'},
  'boolean': {
    'type': 'boolean',
    'map': [false, true, null],
  },
  'number': {'type': 'number'},
  'array': {'type': 'array'},
  'object': {'type': 'object'},
  'any': {'type': 'any'},
};

Object? _deepCopy(Object? v) => switch (v) {
  Map() => <String, Object?>{
    for (final e in v.entries) '${e.key}': _deepCopy(e.value),
  },
  List() => [for (final e in v) _deepCopy(e)],
  _ => v,
};

/// Stand-in for JS `undefined`: a value that is missing, as opposed to `null`.
const Object _absent = _Absent();

final class _Absent {
  const _Absent();
}

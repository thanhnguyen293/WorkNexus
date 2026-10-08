import 'dart:convert';

/// Thrown when a packet does not fit the server's `apiScheme`. Internal to the
/// xxd datasource, which maps it to a `Failure` before it leaves `data/`.
final class ApiSchemeException implements Exception {
  const ApiSchemeException(this.message);

  final String message;

  @override
  String toString() => 'ApiSchemeException: $message';
}

/// Dart port of the xuanxuan "JSONOptimizer" (zentaoclient 9.1.2): packs socket
/// packets into positional arrays described by the `apiScheme` that xxd returns
/// from `serverInfo`, and unpacks the server's replies.
///
/// It mirrors the JS implementation branch for branch, quirks included,
/// because xxd decodes with the same rules. In particular it keeps JS's
/// distinction between `undefined` (a missing map key, [_absent]) and `null`:
/// an absent value takes the scheme default, `null` does not.
///
/// The scheme is versioned (`$version`) and must come from the server on every
/// login — never hard-code one.
final class ApiSchemeCodec {
  ApiSchemeCodec(Map<String, Object?> scheme)
    : _scheme = {..._builtInSchemes, ...scheme};

  final Map<String, Object?> _scheme;
  final Map<String, Map<String, Object?>> _cache = {};
  List<String>? _schemeNames;
  Map<String, int>? _schemeIndex;

  String? get version => _scheme[r'$version'] as String?;
  bool get _validation => _truthy(_scheme[r'$validation']);
  bool get _omitDefaultProps => _truthy(_scheme[r'$omitDefaultProps']);
  bool get _encodeName => _scheme[r'$encodeName'] != false;

  /// Packs [data] with the scheme named [name] (or [fallback] when [name] is
  /// not in the scheme). Returns `[name, packed]` unless `$encodeName` is off.
  Object? encode(String name, Object? data, {String? fallback}) {
    final scheme = _dataScheme(name, fallback);
    if (scheme == null) {
      throw ApiSchemeException('Scheme "$name" is not found.');
    }
    final packed = _jsonValue(_encodeValue(scheme, data));
    return _encodeName ? [name, packed] : packed;
  }

  String encodeToJson(String name, Object? data, {String? fallback}) =>
      jsonEncode(encode(name, data, fallback: fallback));

  /// Unpacks [encoded]. With `$encodeName` (the default) the scheme name — or
  /// its index in the sorted scheme names — is read from `encoded[0]`;
  /// otherwise [name] must be given.
  Object? decode(Object? encoded, {String? name, String? fallback}) {
    var schemeName = name;
    var payload = encoded;
    if (_encodeName) {
      if (encoded is! List) {
        throw const ApiSchemeException(
          'Encoded data must be an array when "encodeName" is on.',
        );
      }
      final head = encoded.isEmpty ? null : encoded[0];
      schemeName = switch (head) {
        num() => _schemeNameByIndex(head),
        String() => head,
        _ => null,
      };
      payload = encoded.length > 1 ? encoded[1] : _absent;
    }
    if (schemeName == null) {
      throw const ApiSchemeException('Scheme name is null on decode.');
    }
    final scheme = _dataScheme(schemeName, fallback);
    if (scheme == null) {
      throw ApiSchemeException('Scheme "$schemeName" is not found.');
    }
    return _jsonValue(_decodeValue(scheme, payload));
  }

  Object? decodeFromJson(String json, {String? name, String? fallback}) =>
      decode(jsonDecode(json), name: name, fallback: fallback);

  // ---- scheme resolution ---------------------------------------------------

  Map<String, Object?>? _dataScheme(String? name, [String? fallback]) {
    if (name == null) return null;
    final cached = _cache[name];
    if (cached != null) return cached;
    var raw = _scheme[name];
    if (raw == null && fallback != null) raw = _scheme[fallback];
    if (raw is! Map) return null;
    // Deep copy: formatting rewrites the scheme, and the JS original mutates
    // shared objects in ways a Dart port should not depend on.
    final formatted = _format(_deepCopy(raw) as Map<String, Object?>, name);
    _cache[name] = formatted;
    return formatted;
  }

  Map<String, Object?> _format(Map<String, Object?> scheme, String name) {
    var rt = scheme..['_schemeName'] = name;
    final type = rt['type'];
    if (!_primitiveTypes.contains(type) || name != type) {
      final referenced = _dataScheme(type as String?);
      if (referenced == null) {
        throw ApiSchemeException(
          'The scheme type "$type" referenced in "$name" is not found.',
        );
      }
      rt = _inherit(rt, referenced);
    }
    final extend = rt['extend'];
    if (_truthy(extend)) {
      final parent = _dataScheme(extend as String);
      if (parent == null) {
        throw ApiSchemeException(
          'The scheme type "$extend" extended in "$name" is not found.',
        );
      }
      rt = _extend(rt, parent, name);
    }
    final map = rt['map'];
    if (map is List) {
      rt['_mapForEncode'] = [
        for (final v in map) _isJsObject(v) ? jsonEncode(v) : v,
      ];
    } else if (map is Map) {
      rt['_mapForEncode'] = {
        for (final e in map.entries)
          '${e.key}': _isJsObject(e.value) ? jsonEncode(e.value) : e.value,
      };
    }
    final props = rt['props'];
    if (props is List && props.isNotEmpty) {
      final formatted = <Map<String, Object?>>[];
      for (var i = 0; i < props.length; ++i) {
        final prop = Map<String, Object?>.of(props[i] as Map<String, Object?>);
        final propName = prop['name'];
        if (!_truthy(propName)) {
          throw ApiSchemeException(
            'Property $i of scheme "$name" has no name.',
          );
        }
        final f = _format(prop, '$name.$propName');
        final typeScheme = _dataScheme(f['type'] as String?);
        if (typeScheme == null) {
          throw ApiSchemeException('Type of "$name.$propName" is not found.');
        }
        formatted.add(_inherit(f, typeScheme));
      }
      rt['props'] = formatted;
    }
    return rt;
  }

  /// JS `{...referenced, ...own, type: referenced.type}`.
  static Map<String, Object?> _inherit(
    Map<String, Object?> own,
    Map<String, Object?> referenced,
  ) => {...referenced, ...own, 'type': referenced['type']};

  /// Parent props first; a child prop with the same name replaces it in place.
  static Map<String, Object?> _extend(
    Map<String, Object?> child,
    Map<String, Object?> parent,
    String name,
  ) {
    final parentProps = parent['props'];
    if (parentProps is! List || parentProps.isEmpty) return child;
    final childProps = child['props'];
    if (childProps is! List) {
      // The JS original crashes here (reads `.length` of undefined).
      throw ApiSchemeException('Scheme "$name" extends without props.');
    }
    if (childProps.isEmpty) return child;
    final merged = [...parentProps];
    final indexByName = {
      for (var i = 0; i < merged.length; ++i) (merged[i] as Map)['name']: i,
    };
    for (final prop in childProps) {
      final at = indexByName[(prop as Map)['name']];
      if (at != null) {
        merged[at] = prop;
      } else {
        merged.add(prop);
      }
    }
    return {...child, 'props': merged};
  }

  String? _schemeNameByIndex(num index) {
    final names = _sortedSchemeNames();
    if (index != index.truncate() || index < 0 || index >= names.length) {
      return null;
    }
    return names[index.toInt()];
  }

  /// Index of [name] in the sorted scheme names — the compact form xxd may use
  /// in place of a scheme name.
  int? schemeIndexOf(String name) => (_schemeIndex ??= {
    for (final (i, n) in _sortedSchemeNames().indexed) n: i,
  })[name];

  List<String> _sortedSchemeNames() =>
      _schemeNames ??= _scheme.keys.where((k) => !k.startsWith(r'$')).toList()
        ..sort();

  // ---- encode --------------------------------------------------------------

  Object? _encodeValue(Map<String, Object?> rt, Object? data) {
    final value = identical(data, _absent) ? _default(rt) : data;
    if (rt['map'] != null) {
      final mapped = _lookupMapIndex(rt['_mapForEncode'], value);
      if (!identical(mapped, _absent)) return mapped;
    }
    if (_validation) _validate(rt, value);
    if (value != null && !identical(value, _absent)) {
      final type = rt['type'];
      if (type == 'object') {
        final props = rt['props'];
        if (props is! List || props.isEmpty) {
          throw ApiSchemeException(
            'Properties are empty in scheme "${rt['_schemeName']}".',
          );
        }
        final packed = <Object?>[];
        var lastNonDefault = -1;
        for (var i = 0; i < props.length; ++i) {
          final prop = props[i] as Map<String, Object?>;
          final name = prop['name'];
          final propValue = value is Map && value.containsKey(name)
              ? value[name]
              : _absent;
          if (_omitDefaultProps && !_jsEquals(propValue, _default(prop))) {
            lastNonDefault = i;
          }
          packed.add(_jsonValue(_encodeValue(prop, propValue)));
        }
        // Mirrors JS: trailing defaults are dropped only when at least one prop
        // differs from its default.
        if (_omitDefaultProps &&
            lastNonDefault > -1 &&
            lastNonDefault < props.length - 1) {
          packed.removeRange(lastNonDefault + 1, props.length);
        }
        return packed;
      }
      if (type == 'array' && value is List && value.isNotEmpty) {
        final itemScheme = _arrayItemScheme(rt);
        return [
          for (final item in value) _jsonValue(_encodeValue(itemScheme, item)),
        ];
      }
      if ((type == 'string' && value is! String) ||
          (type == 'number' && value is! num) ||
          (type == 'boolean' && value is! bool)) {
        throw ApiSchemeException(
          'Value type ${value.runtimeType} does not match "$type" of scheme '
          '"${rt['_schemeName']}".',
        );
      }
    }
    return value;
  }

  /// JS `De`: position (array map) or key (object map) of [value].
  static Object? _lookupMapIndex(Object? mapForEncode, Object? value) {
    final needle = _isJsObject(value) ? jsonEncode(value) : value;
    if (mapForEncode is List) {
      for (var i = 0; i < mapForEncode.length; ++i) {
        if (_strictEquals(mapForEncode[i], needle)) return i;
      }
    } else if (mapForEncode is Map) {
      for (final e in mapForEncode.entries) {
        if (_strictEquals(e.value, needle)) return e.key;
      }
    }
    return _absent;
  }

  void _validate(Map<String, Object?> rt, Object? value) {
    if (identical(value, _absent) && _truthy(rt['required'])) {
      throw ApiSchemeException(
        'Value of scheme "${rt['_schemeName']}" is required.',
      );
    }
    final match = rt['match'];
    if (_truthy(match)) {
      if (value == null || identical(value, _absent)) {
        throw ApiSchemeException(
          'Value of scheme "${rt['_schemeName']}" does not match its rule.',
        );
      }
      final text = _isJsObject(value) ? jsonEncode(value) : _jsToString(value);
      if (!RegExp(match as String).hasMatch(text)) {
        throw ApiSchemeException(
          'Value of scheme "${rt['_schemeName']}" does not match its rule.',
        );
      }
    }
  }

  // ---- decode --------------------------------------------------------------

  Object? _decodeValue(Map<String, Object?> rt, Object? value) {
    if (value == null || identical(value, _absent)) return value;
    final map = rt['map'];
    if (map != null && (value is String || value is num)) {
      final mapped = _mapGet(map, value);
      if (!identical(mapped, _absent)) return mapped;
    }
    switch (rt['type']) {
      case 'object':
        if (value is! List) {
          throw ApiSchemeException(
            'Encoded data is not an array for scheme "${rt['_schemeName']}".',
          );
        }
        final props = rt['props'];
        if (props is! List || props.isEmpty) {
          throw ApiSchemeException(
            'Properties are empty in scheme "${rt['_schemeName']}".',
          );
        }
        final out = <String, Object?>{};
        for (var i = 0; i < props.length; ++i) {
          final prop = props[i] as Map<String, Object?>;
          final v = i >= value.length
              ? _default(prop)
              : _decodeValue(prop, value[i]);
          if (!identical(v, _absent)) out[prop['name'] as String] = v;
        }
        return out;
      case 'array':
        if (value is! List) {
          throw ApiSchemeException(
            'Encoded data is not an array for scheme "${rt['_schemeName']}".',
          );
        }
        final itemScheme = _arrayItemScheme(rt);
        return [
          for (final item in value) _jsonValue(_decodeValue(itemScheme, item)),
        ];
      case 'boolean' when value is! bool:
        if (value is num) return value > 0;
        if (value is String) {
          final lower = value.toLowerCase();
          return lower == '1' || lower == 'true';
        }
        return _default(rt);
      case 'number' when value is! num:
        if (value is String) return value.isEmpty ? 0 : _parseFloat(value);
        return _default(rt);
      case 'string' when value is! String:
        return _jsToString(value);
    }
    return value;
  }

  Map<String, Object?> _arrayItemScheme(Map<String, Object?> rt) {
    final arrType = rt['arrType'];
    if (!_truthy(arrType)) {
      throw ApiSchemeException(
        'Array scheme "${rt['_schemeName']}" has no arrType.',
      );
    }
    final scheme = _dataScheme(arrType as String);
    if (scheme == null) {
      throw ApiSchemeException(
        'Array item scheme "$arrType" of "${rt['_schemeName']}" is not found.',
      );
    }
    return scheme;
  }

  /// JS `map[key]` on an array or object map.
  static Object? _mapGet(Object map, Object key) {
    if (map is List) {
      final index = key is num
          ? (key == key.truncate() ? key.toInt() : null)
          : (_canonicalIndex.hasMatch(key as String) ? int.parse(key) : null);
      return index != null && index < map.length ? map[index] : _absent;
    }
    if (map is Map) {
      final k = _jsToString(key);
      return map.containsKey(k) ? map[k] : _absent;
    }
    return _absent;
  }

  // ---- JS semantics helpers --------------------------------------------------

  static Object? _default(Map<String, Object?> rt) =>
      rt.containsKey('default') ? rt['default'] : _absent;

  /// `undefined` serialises as `null` inside JSON arrays.
  static Object? _jsonValue(Object? v) => identical(v, _absent) ? null : v;

  static bool _isJsObject(Object? v) => v == null || v is Map || v is List;

  static bool _truthy(Object? v) =>
      v != null &&
      !identical(v, _absent) &&
      v != false &&
      v != 0 &&
      v != '' &&
      !(v is double && v.isNaN);

  /// JS `===` for the primitives a scheme map can hold.
  static bool _strictEquals(Object? a, Object? b) {
    if (a is num && b is num) return a == b;
    if (identical(a, _absent) || identical(b, _absent)) {
      return identical(a, b);
    }
    return a.runtimeType == b.runtimeType && a == b;
  }

  /// JS `Ce`: deep equality used to detect props still at their default.
  static bool _jsEquals(Object? a, Object? b) {
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

  static List<String> _jsKeys(Object o) => o is Map
      ? [for (final k in o.keys) '$k']
      : [for (var i = 0; i < (o as List).length; ++i) '$i'];

  static Object? _jsGet(Object o, String key) {
    if (o is Map) return o.containsKey(key) ? o[key] : _absent;
    final i = int.tryParse(key);
    final list = o as List;
    return i != null && i >= 0 && i < list.length ? list[i] : _absent;
  }

  static String _jsToString(Object? v) {
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
  static num? _parseFloat(String s) {
    final m = _floatPrefix.firstMatch(s);
    if (m == null) return null;
    final d = double.parse(m.group(1)!);
    return d.isFinite && d == d.truncateToDouble() && d.abs() < 9007199254740992
        ? d.toInt()
        : d;
  }

  static final _canonicalIndex = RegExp(r'^(0|[1-9]\d*)$');
  static final _floatPrefix = RegExp(
    r'^\s*([+-]?(?:Infinity|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?))',
  );

  static const _primitiveTypes = {
    'any',
    'string',
    'number',
    'boolean',
    'object',
    'array',
  };

  static const Map<String, Object?> _builtInSchemes = {
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

  static Object? _deepCopy(Object? v) => switch (v) {
    Map() => <String, Object?>{
      for (final e in v.entries) '${e.key}': _deepCopy(e.value),
    },
    List() => [for (final e in v) _deepCopy(e)],
    _ => v,
  };
}

/// Stand-in for JS `undefined`: a value that is missing, as opposed to `null`.
const Object _absent = _Absent();

final class _Absent {
  const _Absent();
}

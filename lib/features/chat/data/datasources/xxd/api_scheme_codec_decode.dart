part of 'api_scheme_codec.dart';

/// Unpacking the server's positional arrays back into maps and values.
mixin _SchemeDecoding on _ApiSchemeCodecCore {
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
}

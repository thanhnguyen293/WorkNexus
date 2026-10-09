part of 'api_scheme_codec.dart';

/// Packing values into the scheme's positional arrays, with validation.
mixin _SchemeEncoding on _ApiSchemeCodecCore {
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
}

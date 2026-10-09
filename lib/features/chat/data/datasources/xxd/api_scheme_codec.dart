import 'dart:convert';

part 'api_scheme_codec_encode.dart';
part 'api_scheme_codec_decode.dart';
part 'api_scheme_codec_js.dart';

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
final class ApiSchemeCodec extends _ApiSchemeCodecCore
    with _SchemeEncoding, _SchemeDecoding {
  ApiSchemeCodec(super.scheme);
}

/// Scheme state and resolution shared by encoding and decoding: the server's
/// scheme, the formatted-scheme cache and the scheme-name index.
abstract class _ApiSchemeCodecCore {
  _ApiSchemeCodecCore(Map<String, Object?> scheme)
    : _scheme = {..._builtInSchemes, ...scheme};

  final Map<String, Object?> _scheme;
  final Map<String, Map<String, Object?>> _cache = {};
  List<String>? _schemeNames;
  Map<String, int>? _schemeIndex;

  String? get version => _scheme[r'$version'] as String?;
  bool get _validation => _truthy(_scheme[r'$validation']);
  bool get _omitDefaultProps => _truthy(_scheme[r'$omitDefaultProps']);
  bool get _encodeName => _scheme[r'$encodeName'] != false;

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
}

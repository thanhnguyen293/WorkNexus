import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/api_scheme_codec.dart';

// Golden cases produced by the original JS optimizer (tool/xxd_fixtures.mjs):
// the Dart port must pack and unpack byte-for-byte the same way.
Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/xxd/$name').readAsStringSync())
        as Map<String, Object?>;

void main() {
  group('real apiScheme (server v9.2.2)', () {
    final scheme = _fixture('api_scheme.json');
    final fixture = _fixture('codec_cases.json');
    final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();

    test('scheme version matches the fixture', () {
      expect(ApiSchemeCodec(scheme).version, fixture['schemeVersion']);
    });

    for (final c in cases) {
      final name = c['name']! as String;
      final label = '$name #${c['variant'] ?? '-'}';

      if (c['schemeError'] == true) {
        test('$label: unresolvable scheme throws', () {
          expect(
            () =>
                ApiSchemeCodec(scheme).encode(name, const <String, Object?>{}),
            throwsA(isA<ApiSchemeException>()),
          );
        });
        continue;
      }

      test('$label: encode', () {
        final codec = ApiSchemeCodec(scheme);
        final fallback = c['fallback'] as String?;
        if (c.containsKey('encodeError')) {
          expect(
            () => codec.encode(name, c['input'], fallback: fallback),
            throwsA(isA<ApiSchemeException>()),
          );
          return;
        }
        expect(
          codec.encode(name, c['input'], fallback: fallback),
          c['encoded'],
        );
      });

      if (c.containsKey('decoded')) {
        test('$label: decode by name and by index', () {
          final codec = ApiSchemeCodec(scheme);
          final encoded = c['encoded']! as List;
          expect(codec.decode(encoded), c['decoded']);
          expect(codec.schemeIndexOf(name), c['index']);
          expect(codec.decode([c['index'], encoded[1]]), c['decoded']);
        });
      }

      if (c.containsKey('mutatedDecoded')) {
        test('$label: decode coerces loosely typed values', () {
          expect(
            ApiSchemeCodec(scheme).decode(c['mutated']),
            c['mutatedDecoded'],
          );
        });
      }
    }
  });

  group('synthetic edge scheme', () {
    final fixture = _fixture('edge_cases.json');
    final scheme = fixture['scheme']! as Map<String, Object?>;

    for (final c in (fixture['cases']! as List).cast<Map<String, Object?>>()) {
      final name = c['name']! as String;
      final fallback = c['fallback'] as String?;
      test('encode/decode $name ${jsonEncode(c['input'])}', () {
        final codec = ApiSchemeCodec(scheme);
        if (c.containsKey('error')) {
          expect(
            () => codec.encode(name, c['input'], fallback: fallback),
            throwsA(isA<ApiSchemeException>()),
          );
          return;
        }
        expect(
          codec.encode(name, c['input'], fallback: fallback),
          c['encoded'],
        );
        expect(
          ApiSchemeCodec(scheme).decode(c['encoded'], fallback: fallback),
          c['decoded'],
        );
      });
    }

    for (final c
        in (fixture['decodes']! as List).cast<Map<String, Object?>>()) {
      test('decode ${jsonEncode(c['encoded'])}', () {
        final codec = ApiSchemeCodec(scheme);
        if (c.containsKey('error')) {
          expect(
            () => codec.decode(c['encoded']),
            throwsA(isA<ApiSchemeException>()),
          );
          return;
        }
        expect(codec.decode(c['encoded']), c['decoded']);
      });
    }

    test('scheme index follows the sorted scheme names', () {
      final index = fixture['index']! as Map<String, Object?>;
      expect(
        ApiSchemeCodec(scheme).schemeIndexOf(index['name']! as String),
        index['index'],
      );
    });

    test('decoding without a scheme name throws', () {
      expect(
        () => ApiSchemeCodec(scheme).decode([9999, <Object?>[]]),
        throwsA(isA<ApiSchemeException>()),
      );
      expect(
        () => ApiSchemeCodec(scheme).decode('not an array'),
        throwsA(isA<ApiSchemeException>()),
      );
    });
  });
}

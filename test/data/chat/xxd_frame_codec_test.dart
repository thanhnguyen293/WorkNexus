import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/api_scheme_codec.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_cipher.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_frame_codec.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_packet.dart';

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/xxd/$name').readAsStringSync())
        as Map<String, Object?>;

void main() {
  final scheme = _fixture('api_scheme.json');
  const token = '0123456789abcdef0123456789abcdef';

  XxdFrameCodec codecWith({String serverName = '', bool aes = true}) =>
      XxdFrameCodec(
        clientVersion: '9.1.2',
        lang: 'vi',
        serverName: serverName,
        scheme: ApiSchemeCodec(scheme),
        cipher: aes ? XxdCipher(token) : null,
      );

  group('requests', () {
    final fixture = _fixture('frame_cases.json');
    for (final c in (fixture['cases']! as List).cast<Map<String, Object?>>()) {
      final r = c['request']! as Map<String, Object?>;
      test('${r['method']} packs like the JS client', () {
        final request = XxdRequest(
          r['method']! as String,
          params: r['params'] as List<Object?>?,
          rid: r['rid'] as String?,
          userId: r['userID'] as int?,
        );
        expect(codecWith().encodeToText(request), c['text']);
      });
    }

    test('userlogin is prefixed with the server name', () {
      final text = codecWith(serverName: 'srv').encodeToText(
        const XxdRequest('userLogin', params: ['srv', 'demo', 'x', {}]),
      );
      expect(text, startsWith('srv["userloginRequest"'));
    });

    test('encrypted frames decrypt back to the packed text', () {
      final codec = codecWith();
      const request = XxdRequest('ping', userId: 40);
      final frame = codec.encode(request) as List<int>;
      expect(XxdCipher(token).decrypt(frame), codec.encodeToText(request));
    });

    test('without a scheme the request is plain JSON', () {
      const codec = XxdFrameCodec(clientVersion: '9.1.2', lang: 'en');
      final text = codec.encode(const XxdRequest('ping', rid: 'r1')) as String;
      expect(jsonDecode(text), {
        'version': '9.1.2',
        'device': 'desktop',
        'lang': 'en',
        'method': 'ping',
        'rid': 'r1',
      });
    });
  });

  group('responses', () {
    final cases = (_fixture('codec_cases.json')['cases']! as List)
        .cast<Map<String, Object?>>();

    test('decrypts and unpacks a pushed messagesend', () {
      final c = cases.firstWhere(
        (c) => c['name'] == 'messagesendResponse' && c['variant'] == 0,
      );
      final frame = XxdCipher(token).encrypt(jsonEncode(c['encoded']));
      final packets = codecWith().decode(frame);
      expect(packets, hasLength(1));
      expect(packets.single.raw, c['decoded']);
      expect(packets.single.apiName, isNotEmpty);
    });

    test('a JSON array without a scheme is a batch of packets', () {
      const codec = XxdFrameCodec(clientVersion: '9.1.2', lang: 'en');
      final packets = codec.decode(
        '[{"method":"ping"},{"method":"chatGetList","result":"fail"}]',
      );
      expect(packets.map((p) => p.apiName), ['ping', 'chatgetlist']);
      expect(packets.map((p) => p.isSuccess), [true, false]);
    });

    test('garbage frames raise XxdProtocolException', () {
      final codec = codecWith();
      expect(
        () => codec.decode(utf8.encode('not encrypted')),
        throwsA(isA<XxdProtocolException>()),
      );
      expect(
        () => codec.decodeText('{oops'),
        throwsA(isA<XxdProtocolException>()),
      );
      // An unknown scheme name falls back to `responsePack` (as in JS), but a
      // payload that is not positional props cannot be unpacked.
      expect(
        () => codec.decodeText('["noSuchScheme", "not props"]'),
        throwsA(isA<XxdProtocolException>()),
      );
    });
  });

  // Local-only check against frames captured from a real server with
  // `xuanxuan_probe.mjs --dump-frames <dir>`. They hold real chat data, so they
  // are never committed: point XXD_FRAMES_DIR + XXD_SCHEME at them to run.
  final framesDir = Platform.environment['XXD_FRAMES_DIR'];
  final schemePath = Platform.environment['XXD_SCHEME'];
  group(
    'captured frames',
    () {
      test('decode exactly like the JS client', () {
        final codec = XxdFrameCodec(
          clientVersion: '9.1.2',
          lang: 'vi',
          scheme: ApiSchemeCodec(
            jsonDecode(File(schemePath!).readAsStringSync())
                as Map<String, Object?>,
          ),
        );
        final raws =
            Directory(framesDir!)
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.raw.json'))
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));
        expect(raws, isNotEmpty);
        for (final raw in raws) {
          final expected = jsonDecode(
            File(
              raw.path.replaceFirst('.raw.json', '.decoded.json'),
            ).readAsStringSync(),
          );
          final packets = codec.decodeText(raw.readAsStringSync());
          expect(
            packets.length == 1
                ? packets.single.raw
                : packets.map((p) => p.raw).toList(),
            expected,
            reason: raw.path,
          );
        }
      });
    },
    skip: framesDir == null || schemePath == null
        ? 'set XXD_FRAMES_DIR and XXD_SCHEME to run'
        : false,
  );
}

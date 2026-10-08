import 'dart:convert';

import 'api_scheme_codec.dart';
import 'xxd_cipher.dart';
import 'xxd_packet.dart';

/// Thrown when a socket frame cannot be turned into packets. Internal to the
/// xxd datasource, which maps it to a `Failure`.
final class XxdProtocolException implements Exception {
  const XxdProtocolException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'XxdProtocolException: $message';
}

/// Converts between [XxdRequest]/[XxdResponse] and WebSocket frames, applying
/// the session's `apiScheme` packing and AES encryption when enabled.
///
/// Wire rules (from the 9.1.2 client):
/// - request JSON = `{version, device, lang, method (lower-case), params?, rid?,
///   userID?, module?}`;
/// - with a scheme it is packed as `<apiName>Request` (fallback `requestPack`),
///   and the `userlogin` packet is prefixed with the server name;
/// - with AES the frame is binary ciphertext, otherwise a text frame;
/// - with a scheme every incoming frame is one packed packet; without one a
///   frame may also hold a JSON array of packets.
final class XxdFrameCodec {
  const XxdFrameCodec({
    required this.clientVersion,
    required this.lang,
    this.device = 'desktop',
    this.serverName = '',
    this.scheme,
    this.cipher,
  });

  final String clientVersion;
  final String lang;
  final String device;
  final String serverName;
  final ApiSchemeCodec? scheme;
  final XxdCipher? cipher;

  /// The frame to send: `List<int>` (binary) when encrypted, else `String`.
  Object encode(XxdRequest request) {
    final text = encodeToText(request);
    return cipher?.encrypt(text) ?? text;
  }

  /// The request as the (pre-encryption) text the server parses.
  String encodeToText(XxdRequest request) {
    final data = <String, Object?>{
      'version': clientVersion,
      'device': device,
      'lang': lang,
      'method': request.method.toLowerCase(),
      if (request.params != null) 'params': request.params,
      if (request.rid != null) 'rid': request.rid,
      if (request.userId != null) 'userID': request.userId,
      if (request.module != null && request.module != 'im')
        'module': request.module,
    };
    final scheme = this.scheme;
    if (scheme == null) return jsonEncode(data);
    final String packed;
    try {
      packed = scheme.encodeToJson(
        '${request.apiName}Request',
        data,
        fallback: 'requestPack',
      );
    } on ApiSchemeException catch (e) {
      throw XxdProtocolException('Cannot pack ${request.apiName}', cause: e);
    }
    return request.apiName == 'userlogin' ? '$serverName$packed' : packed;
  }

  /// Packets carried by one incoming frame ([frame] is `String` or `List<int>`).
  List<XxdResponse> decode(Object frame) {
    final String text;
    try {
      text = switch (frame) {
        String() => frame,
        List<int>() when cipher != null => cipher!.decrypt(frame),
        List<int>() => utf8.decode(frame),
        _ => throw XxdProtocolException(
          'Unsupported frame type ${frame.runtimeType}',
        ),
      };
    } on XxdProtocolException {
      rethrow;
    } catch (e) {
      throw XxdProtocolException('Cannot decrypt frame', cause: e);
    }
    return decodeText(text);
  }

  /// Packets in an already-decrypted frame.
  List<XxdResponse> decodeText(String text) {
    try {
      final json = jsonDecode(text);
      final scheme = this.scheme;
      if (scheme != null && json is List) {
        return [
          XxdResponse.fromJson(scheme.decode(json, fallback: 'responsePack')),
        ];
      }
      if (json is List) return [for (final p in json) XxdResponse.fromJson(p)];
      return [XxdResponse.fromJson(json)];
    } on FormatException catch (e) {
      throw XxdProtocolException('Malformed frame', cause: e);
    } on ApiSchemeException catch (e) {
      throw XxdProtocolException('Cannot unpack frame', cause: e);
    }
  }
}

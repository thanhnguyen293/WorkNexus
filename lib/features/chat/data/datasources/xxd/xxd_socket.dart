import 'dart:async';
import 'dart:io';

/// Minimal WebSocket surface the xxd connection needs, so tests can swap in a
/// fake server.
abstract interface class XxdSocket {
  /// Incoming frames: `String` (text) or `List<int>` (binary).
  Stream<Object> get frames;

  /// Sends a `String` as a text frame or `List<int>` as a binary frame.
  void send(Object frame);

  Future<void> close([int? code, String? reason]);

  int? get closeCode;
  String? get closeReason;
}

/// Opens a socket to [url] using [client] for the TLS handshake.
typedef XxdSocketConnector =
    Future<XxdSocket> Function(Uri url, HttpClient client);

/// Production connector backed by `dart:io` [WebSocket].
Future<XxdSocket> connectIoXxdSocket(Uri url, HttpClient client) async =>
    _IoXxdSocket(
      await WebSocket.connect(
        url.toString(),
        customClient: client,
      ).timeout(const Duration(seconds: 20)),
    );

final class _IoXxdSocket implements XxdSocket {
  _IoXxdSocket(this._ws);

  final WebSocket _ws;

  @override
  Stream<Object> get frames => _ws.cast<Object>();

  @override
  void send(Object frame) => _ws.add(frame);

  @override
  Future<void> close([int? code, String? reason]) => _ws.close(code, reason);

  @override
  int? get closeCode => _ws.closeCode;

  @override
  String? get closeReason => _ws.closeReason;
}

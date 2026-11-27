import 'dart:async';
import 'dart:io';

import '../ext/log_ext.dart';

/// HTTP request terminator sequence, used to indicate the end of HTTP headers.
const String httpTerminal = '\r\n\r\n';

/// [WorkNexus patch] Per accepted socket: completes when the player drops the
/// connection (see [LocalProxyServer]).
final Expando<Completer<void>> _peerGone = Expando('peerGone');

/// [WorkNexus patch] Whether the player is still on the other end.
extension SocketPeer on Socket {
  /// Starts tracking this socket; the returned completer is completed when
  /// its read side ends.
  Completer<void> trackPeer() => _peerGone[this] ??= Completer<void>();

  /// Whether the player has dropped this connection.
  bool get peerClosed => _peerGone[this]?.isCompleted ?? false;

  /// Closes the socket once what was written is sent — or at once when the
  /// player has left, as closing waits for a flush a reset socket never
  /// completes.
  Future<void> closeOrDestroy() async {
    if (peerClosed) {
      destroy();
      return;
    }
    try {
      await close();
    } catch (_) {
      destroy();
    }
  }
}

/// Extension on the [Socket] class to provide additional utility methods.
extension SocketExtension on Socket {
  /// Appends data to the socket.
  ///
  /// - If [data] is a [String], it writes the string followed by the HTTP terminal sequence.
  /// - If [data] is a [Stream<List<int>>], it adds the stream to the socket.
  /// - If [data] is a [List<int>]:
  ///   - On iOS, if the data length is greater than 100,000 bytes, it splits the data into chunks of 100,000 bytes,
  ///     sending each chunk with a 10ms delay to avoid potential issues with large data writes.
  ///   - On other platforms, it writes the entire data at once.
  ///
  /// Returns `true` if the operation succeeds, otherwise logs a warning and returns `false`.
  Future<bool> append(Object data) async {
    try {
      if (data is String) {
        // Write string data with HTTP terminal.
        write('$data$httpTerminal');
      } else if (data is Stream<List<int>>) {
        // Add stream data to the socket.
        await addStream(data);
      } else if (data is List<int>) {
        if (Platform.isIOS) {
          // if (data.length <= 100000) {
          add(data);
          // } else {
          // On iOS, split large data into chunks to avoid issues.
          //   await split(data);
          // }
        } else {
          // On other platforms, write all data at once.
          add(data);
        }
      }
      return true;
    } catch (e) {
      // Log a warning if the socket is closed or an error occurs.
      logW("Socket closed: $e, can't append data");
      return false;
    }
  }

  Future<void> split(List<int> data) async {
    int startIndex = 0, endIndex = 100000;
    while (startIndex < data.length) {
      add(data.sublist(startIndex, endIndex));
      await Future.delayed(Duration(milliseconds: 10));
      startIndex = endIndex;
      endIndex += 100000;
      if (endIndex > data.length) {
        endIndex = data.length;
      }
    }
  }
}

import 'package:talker_flutter/talker_flutter.dart';

import '../../../../../core/debug/app_talker.dart';
import '../../../../../core/error/failure.dart';
import 'xxd_connection_state.dart';
import 'xxd_packet.dart';

/// Writes the chat socket's traffic to the debug panel, beside the HTTP log.
///
/// Only method names, outcomes and timings are logged — never params or
/// payloads, which carry message text and the login password.
class XxdTrafficLog {
  const XxdTrafficLog([this._talker]);

  final Talker? _talker;

  Talker get _out => _talker ?? appTalker;

  void request(XxdRequest request) {
    if (request.apiName == 'ping') return;
    _out.logCustom(
      XxdLog('→ ${request.method}', key: 'ws-request', level: LogLevel.debug),
    );
  }

  void reply(String apiName, Duration elapsed, XxdResponse packet) {
    final ok = packet.isSuccess;
    _out.logCustom(
      XxdLog(
        '← $apiName ${ok ? 'ok' : 'failed: ${packet.message ?? '-'}'} '
        '(${elapsed.inMilliseconds} ms)',
        key: 'ws-response',
        level: ok ? LogLevel.info : LogLevel.error,
      ),
    );
  }

  void failed(String apiName, Duration elapsed, Failure failure) {
    _out.logCustom(
      XxdLog(
        '← $apiName failed: ${failure.message} '
        '(${elapsed.inMilliseconds} ms)',
        key: 'ws-response',
        level: LogLevel.error,
      ),
    );
  }

  /// A packet the server sent on its own (a new message, a status change…).
  void push(XxdResponse packet) {
    if (packet.apiName == 'ping') return;
    _out.logCustom(
      XxdLog('⇠ ${packet.apiName}', key: 'ws-push', level: LogLevel.verbose),
    );
  }

  void state(XxdConnectionState state) {
    final (text, level) = switch (state) {
      XxdDisconnected() => ('disconnected', LogLevel.info),
      XxdConnecting() => ('connecting', LogLevel.info),
      XxdOnline() => ('online', LogLevel.info),
      XxdReconnecting(:final attempt, :final delay, :final lastFailure) => (
        'reconnecting #$attempt in ${delay.inSeconds} s '
            '(${lastFailure.message})',
        LogLevel.warning,
      ),
      XxdStopped(:final failure) => (
        'stopped: ${failure.message}',
        LogLevel.error,
      ),
    };
    _out.logCustom(XxdLog(text, key: 'ws-state', level: level));
  }
}

/// One chat-socket entry in the debug panel; [key] lets it be filtered there.
class XxdLog extends TalkerLog {
  XxdLog(super.message, {required String key, required LogLevel level})
    : _key = key,
      _level = level;

  final String _key;
  final LogLevel _level;

  @override
  String get key => _key;

  @override
  String get title => _key;

  @override
  LogLevel get logLevel => _level;
}

import 'dart:async';

import '../../domain/value_objects/chat_connection_status.dart';
import '../datasources/xxd/xxd_connection.dart';
import '../datasources/xxd/xxd_connection_state.dart';
import '../datasources/xxd/xxd_packet.dart';
import 'chat_packet_ingestor.dart';

/// One account's live connection plus a write queue that applies packets to
/// the DB strictly in arrival order.
class ChatSession {
  ChatSession(this.connection);

  final XxdConnection connection;
  int? selfUserId;
  StreamSubscription<XxdResponse>? _packets;
  StreamSubscription<XxdConnectionState>? _states;
  Future<void> _tail = Future.value();
  void Function(Object, StackTrace)? _onError;

  bool get isOnline => connection.state is XxdOnline;

  bool get isActive => switch (connection.state) {
    XxdStopped() || XxdDisconnected() => false,
    _ => true,
  };

  void listen({
    required void Function(XxdResponse) onPacket,
    required void Function(XxdConnectionState) onState,
    required void Function(Object error, StackTrace stack) onError,
  }) {
    _onError = onError;
    _packets = connection.packets.listen(onPacket, onError: onError);
    _states = connection.states.listen(onState);
  }

  /// Runs [task] after every previously queued task. Failures are reported to
  /// the error sink (they have no caller) and do not block later tasks.
  Future<void> enqueue(Future<void> Function() task) {
    final run = _tail.then((_) => task());
    _tail = run.catchError((Object e, StackTrace s) => _onError?.call(e, s));
    return _tail;
  }

  /// Requests what the DB is missing. Fire-and-forget: the replies come back
  /// as packets and are ingested like any other.
  void fetchMissing(IngestFollowUp followUp) {
    if (followUp.userIds.isNotEmpty) {
      unawaited(
        connection.request(
          XxdRequest('usergetlist', params: [followUp.userIds.toList()]),
        ),
      );
    }
    for (final gid in followUp.chatGids) {
      unawaited(connection.request(XxdRequest('chatgetbygid', params: [gid])));
    }
  }

  Future<void> close() async {
    await _packets?.cancel();
    await _states?.cancel();
    await connection.dispose();
  }
}

/// Latest [ChatConnectionStatus] of an account, replayed to new listeners.
class StatusChannel {
  ChatConnectionStatus _value = const ChatConnectionStatus.offline();
  final _changes = StreamController<ChatConnectionStatus>.broadcast();

  void set(ChatConnectionStatus status) {
    if (status == _value) return;
    _value = status;
    _changes.add(status);
  }

  Stream<ChatConnectionStatus> watch() async* {
    yield _value;
    yield* _changes.stream;
  }
}

/// Re-emits [source] mapped with the latest value of [selfUserId] (the
/// account's chat user id, needed to tell own messages and chat peers apart).
Stream<R> withSelfUserId<T, R>(
  Stream<int?> selfUserId,
  Stream<T> source,
  R Function(T value, int? self) combine,
) {
  late StreamController<R> out;
  StreamSubscription<int?>? selfSub;
  StreamSubscription<T>? sourceSub;
  int? self;
  var hasSelf = false;
  T? last;
  var hasLast = false;
  void emit() {
    if (hasSelf && hasLast) out.add(combine(last as T, self));
  }

  out = StreamController<R>(
    onListen: () {
      selfSub = selfUserId.listen((v) {
        self = v;
        hasSelf = true;
        emit();
      }, onError: out.addError);
      sourceSub = source.listen((v) {
        last = v;
        hasLast = true;
        emit();
      }, onError: out.addError);
    },
    onCancel: () async {
      await selfSub?.cancel();
      await sourceSub?.cancel();
    },
  );
  return out.stream;
}

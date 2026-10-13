import '../../domain/entities/chat_conversation.dart';

/// Sends one typing signal for [chat].
typedef ChatTypingSend =
    void Function(ChatConversation chat, {required bool typing});

/// Turns composer edits into typing signals: "typing" at most once per
/// [interval] while the text changes, then "stopped" once when the text is
/// sent or cleared, or the chat is closed ([stop]).
class ChatTypingSender {
  ChatTypingSender({
    required ChatTypingSend send,
    required ChatConversation? Function() chat,
    required bool Function() enabled,
    DateTime Function() now = DateTime.now,
    this.interval = const Duration(seconds: 3),
  }) : _send = send,
       _chat = chat,
       _enabled = enabled,
       _now = now;

  final ChatTypingSend _send;
  final ChatConversation? Function() _chat;

  /// The user's "show when I'm typing" setting.
  final bool Function() _enabled;
  final DateTime Function() _now;
  final Duration interval;

  String _text = '';
  DateTime? _lastTyping;

  /// The chat the current burst was announced in, so the stop reaches it
  /// even once the chat itself is gone.
  ChatConversation? _announced;

  /// Called on every composer change with its text.
  void changed(String text) {
    // Selection moves notify too; only an edit counts as typing.
    if (text == _text) return;
    _text = text;
    if (text.trim().isEmpty) return stop();
    final now = _now();
    final last = _lastTyping;
    if (last != null && now.difference(last) < interval) return;
    if (!_enabled()) return;
    final chat = _announced ?? _chat();
    if (chat == null) return;
    _announced = chat;
    _lastTyping = now;
    _send(chat, typing: true);
  }

  /// Ends the burst, if one was announced.
  void stop() {
    final chat = _announced;
    _announced = null;
    _lastTyping = null;
    if (chat != null) _send(chat, typing: false);
  }
}

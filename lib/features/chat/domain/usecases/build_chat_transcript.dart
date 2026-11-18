import '../entities/chat_message.dart';
import '../value_objects/message_content.dart';

/// Writes chat messages as the plain-text transcript an AI prompt quotes,
/// oldest first, one message a line: `[18/11 09:05] Lan: the text`.
///
/// Deleted messages and the server's notices are left out; a picture or a
/// file is named rather than sent. Each message is cut to [maxMessageChars]
/// and, when the whole would pass [maxChars], the oldest messages are dropped
/// so the newest — what a summary or a reply needs most — always fit.
class BuildChatTranscript {
  const BuildChatTranscript({
    this.maxChars = 12000,
    this.maxMessageChars = 600,
  });

  final int maxChars;
  final int maxMessageChars;

  /// Mentions are sent as `[@Name](@#id)`; the model only needs `@Name`.
  static final _mention = RegExp(r'\[@([^\]]+)\]\(@#\d+\)');

  /// [nameOf] names a sender by user id; the user's own messages are written
  /// as [selfName]. Returns the transcript and how many messages it holds.
  ({String text, int count}) call(
    List<ChatMessage> messages, {
    required String Function(int userId) nameOf,
    required String selfName,
  }) {
    final ordered = [...messages]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final byServerId = {
      for (final m in ordered)
        if (m.serverId != null) m.serverId!: m,
    };
    String sender(ChatMessage m) => m.isMine ? selfName : nameOf(m.senderId);

    final lines = <String>[];
    var total = 0;
    for (final message in ordered.reversed) {
      if (message.deleted || message.isNotice) continue;
      final body = _bodyOf(message.content);
      if (body == null || body.trim().isEmpty) continue;
      final parent = byServerId[message.replyToId];
      final reply = parent == null ? '' : ' (↪ ${sender(parent)})';
      final line =
          '[${_stamp(message.sentAt)}] ${sender(message)}$reply: '
          '${_clip(body)}';
      if (total + line.length > maxChars && lines.isNotEmpty) break;
      lines.add(line);
      total += line.length + 1;
    }
    return (text: lines.reversed.join('\n'), count: lines.length);
  }

  String? _bodyOf(MessageContent content) => switch (content) {
    TextContent(:final text) => text.replaceAllMapped(
      _mention,
      (m) => '@${m[1]}',
    ),
    EmojiContent(:final emoji) => emoji,
    ImageContent() => '[image]',
    FileContent(:final name) => '[file: $name]',
    LinkContent(:final url, :final title) =>
      title == null ? url : '$title ($url)',
    CodeContent(:final code, :final language) =>
      '[code${language == null ? '' : ' $language'}] $code',
    NotificationContent(:final title, :final text) => [
      ?title,
      text,
    ].where((part) => part.trim().isNotEmpty).join(': '),
    UnsupportedContent() => null,
  };

  /// One line per message: line breaks become spaces.
  String _clip(String text) {
    final flat = text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
    return flat.length <= maxMessageChars
        ? flat
        : '${flat.substring(0, maxMessageChars)}…';
  }

  static String _stamp(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = at.toLocal();
    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

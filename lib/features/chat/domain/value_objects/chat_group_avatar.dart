import 'dart:convert';

/// A group's avatar: an uploaded image, or a short text on a colour.
sealed class ChatGroupAvatar {
  const ChatGroupAvatar();

  /// Parses xxd's `{type: image|text, data: {...}}` (null when absent or
  /// unusable).
  static ChatGroupAvatar? fromJson(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return fromMap(jsonDecode(json));
    } on FormatException {
      return null;
    }
  }

  static ChatGroupAvatar? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final data = raw['data'];
    if (data is! Map) return null;
    return switch (raw['type']) {
      'image' when data['imgUrl'] is String && data['imgUrl'] != '' =>
        ChatImageAvatar(data['imgUrl']! as String),
      'text' => ChatTextAvatar(
        text: '${data['customText'] ?? ''}',
        color: '${data['bgColor'] ?? ''}',
      ),
      _ => null,
    };
  }
}

final class ChatImageAvatar extends ChatGroupAvatar {
  const ChatImageAvatar(this.url);
  final String url;
}

final class ChatTextAvatar extends ChatGroupAvatar {
  const ChatTextAvatar({required this.text, required this.color});

  /// A few characters (may be empty: the group name's initials are used).
  final String text;

  /// `#RRGGBB` (may be empty: the default colour is used).
  final String color;
}

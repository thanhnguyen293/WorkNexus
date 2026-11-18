/// Who may post in a group: everyone, its owner and admins, or chosen
/// members.
enum ChatSendScope { everyone, admins, selected }

/// xxd's `committers` as a value: empty or `$ALL` lets everyone post,
/// `$ADMINS` only the owner and admins, anything else is a comma list of the
/// user ids that may (the owner always may).
final class ChatCommitters {
  const ChatCommitters(this.scope, [this.userIds = const {}]);

  factory ChatCommitters.parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == r'$ALL') {
      return const ChatCommitters(ChatSendScope.everyone);
    }
    if (value == r'$ADMINS') return const ChatCommitters(ChatSendScope.admins);
    return ChatCommitters(ChatSendScope.selected, {
      for (final id in value.split(',')) ?int.tryParse(id.trim()),
    });
  }

  final ChatSendScope scope;

  /// Who may post when [scope] is [ChatSendScope.selected].
  final Set<int> userIds;

  /// The `committers` string xxd stores.
  String encode() => switch (scope) {
    ChatSendScope.everyone => '',
    ChatSendScope.admins => r'$ADMINS',
    ChatSendScope.selected => (userIds.toList()..sort()).join(','),
  };
}

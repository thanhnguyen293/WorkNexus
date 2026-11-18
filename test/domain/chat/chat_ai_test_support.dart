import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_ai_text_generator.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

class MockChatAiTextGenerator extends Mock implements ChatAiTextGenerator {}

/// A text message from [sender] (user id) at [minute] past 09:00.
ChatMessage chatText(
  String text, {
  int sender = 2,
  int minute = 0,
  bool mine = false,
  int? serverId,
  int? replyTo,
  MessageContent? content,
  bool deleted = false,
  bool notice = false,
}) => ChatMessage(
  accountId: 'a',
  gid: 'g$minute$text',
  chatGid: 'c',
  senderId: sender,
  sentAt: DateTime(2026, 11, 18, 9, minute),
  content: content ?? TextContent(text),
  isMine: mine,
  serverId: serverId,
  replyToId: replyTo,
  deleted: deleted,
  isNotice: notice,
);

String chatName(int id) => switch (id) {
  2 => 'Lan',
  3 => 'Minh',
  _ => 'User $id',
};

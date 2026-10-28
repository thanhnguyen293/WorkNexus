import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/features/chat/data/mappers/chat_mappers.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message_reaction.dart';

ChatMessageRow _row({
  required String type,
  required String content,
  int? replyTo = 5,
  bool deleted = true,
}) => ChatMessageRow(
  accountId: 'acc',
  gid: 'r1',
  cgid: 'g1',
  serverId: 20,
  messageIndex: 7,
  senderId: 3,
  sentAt: DateTime(2026, 10, 21),
  contentType: type,
  content: content,
  sendState: 'sent',
  deleted: deleted,
  replyToId: replyTo,
  detached: false,
  broadcast: false,
);

void main() {
  test('a retracted reaction whose emoji was kept is still a reaction', () {
    final message = messageFromRow(
      _row(type: 'image', content: '{"type":"emoji","content":":thumbsup:"}'),
    );
    expect(message.isReaction, isTrue);
    expect(message.deleted, isTrue);
  });

  test('an empty retracted image reply may have been a picture', () {
    // How the server sends any retracted image back: nothing says it was an
    // emoji, so it shows as retracted rather than vanishing.
    final message = messageFromRow(_row(type: 'image', content: ''));
    expect(message.isReaction, isFalse);
    expect(message.deleted, isTrue);
  });

  test('a retracted emotion reply is one too', () {
    expect(
      messageFromRow(_row(type: 'emotion', content: '')).isReaction,
      isTrue,
    );
  });

  test('a retracted ordinary reply is not one', () {
    expect(
      messageFromRow(_row(type: 'plain', content: '')).isReaction,
      isFalse,
    );
  });

  test('an image that is not retracted, or not a reply, is not one', () {
    expect(
      messageFromRow(
        _row(type: 'image', content: '', deleted: false),
      ).isReaction,
      isFalse,
    );
    expect(
      messageFromRow(
        _row(type: 'image', content: '', replyTo: null),
      ).isReaction,
      isFalse,
    );
  });
}

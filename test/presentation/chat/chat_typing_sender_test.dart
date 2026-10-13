import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_typing_sender.dart';

void main() {
  const chat = ChatConversation(
    accountId: 'a',
    gid: 'g',
    type: ChatType.group,
    name: 'Team',
  );
  late List<bool> sent;
  late DateTime now;
  late bool enabled;
  late ChatTypingSender sender;

  setUp(() {
    sent = [];
    now = DateTime(2026, 10, 13, 9);
    enabled = true;
    sender = ChatTypingSender(
      send: (c, {required typing}) => sent.add(typing),
      chat: () => chat,
      enabled: () => enabled,
      now: () => now,
    );
  });

  test('announces typing at most once per interval', () {
    sender.changed('h');
    now = now.add(const Duration(seconds: 1));
    sender.changed('he');
    now = now.add(const Duration(seconds: 2));
    sender.changed('hel');

    expect(sent, [true, true]);
  });

  test('a selection move is not an edit', () {
    sender.changed('h');
    now = now.add(const Duration(seconds: 5));
    sender.changed('h');

    expect(sent, [true]);
  });

  test('clearing the text stops the burst once', () {
    sender.changed('hello');
    sender.changed('');
    sender.changed('');
    sender.stop();

    expect(sent, [true, false]);
  });

  test('stop without a burst sends nothing', () {
    sender.stop();

    expect(sent, isEmpty);
  });

  test('sends nothing while the setting is off', () {
    enabled = false;
    sender.changed('hello');
    sender.stop();

    expect(sent, isEmpty);
  });
}

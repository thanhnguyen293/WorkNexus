import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_typing_signal.dart';
import 'package:work_nexus/features/chat/domain/value_objects/typing_roster.dart';

void main() {
  final t0 = DateTime(2026, 10, 13, 9);

  ChatTypingSignal signal(int user, {bool typing = true, String gid = 'g'}) =>
      ChatTypingSignal(chatGid: gid, userId: user, typing: typing);

  test('a typing signal lists the user until it lapses', () {
    final roster = const TypingRoster().apply(signal(7), t0);

    expect(roster.typingIn('g'), [7]);
    expect(roster.nextExpiry, t0.add(TypingRoster.ttl));
    expect(roster.prune(t0.add(const Duration(seconds: 4))).typingIn('g'), [7]);
    expect(roster.prune(t0.add(TypingRoster.ttl)).typingIn('g'), isEmpty);
  });

  test('a repeated signal extends the entry', () {
    final roster = const TypingRoster()
        .apply(signal(7), t0)
        .apply(signal(7), t0.add(const Duration(seconds: 3)));

    final later = t0.add(const Duration(seconds: 6));
    expect(roster.prune(later).typingIn('g'), [7]);
  });

  test('a stop signal removes the user at once', () {
    final roster = const TypingRoster()
        .apply(signal(7), t0)
        .apply(signal(7, typing: false), t0);

    expect(roster.typingIn('g'), isEmpty);
    expect(roster.nextExpiry, isNull);
    expect(roster.expiries, isEmpty);
  });

  test('ignores signals about the signed-in user', () {
    final roster = const TypingRoster().apply(signal(40), t0, selfUserId: 40);

    expect(roster.typingIn('g'), isEmpty);
  });

  test('lists users earliest to start first, per chat', () {
    final roster = const TypingRoster()
        .apply(signal(8), t0)
        .apply(signal(7), t0.add(const Duration(seconds: 1)))
        .apply(signal(9, gid: 'other'), t0);

    expect(roster.typingIn('g'), [8, 7]);
    expect(roster.typingIn('other'), [9]);
    expect(roster.typingIn('none'), isEmpty);
  });
}

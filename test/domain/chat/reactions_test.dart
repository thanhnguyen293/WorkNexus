import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message_reaction.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/build_reactions.dart';
import 'package:work_nexus/features/chat/domain/usecases/build_reply_thread.dart';
import 'package:work_nexus/features/chat/domain/usecases/should_notify_chat_message.dart';
import 'package:work_nexus/features/chat/domain/usecases/toggle_reaction.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

class _Repo extends Mock implements ChatRepository {}

final _t0 = DateTime(2026, 10, 21, 9);

ChatMessage _msg(
  int id, {
  int? replyTo,
  String? emoji,
  int sender = 1,
  bool mine = false,
  bool deleted = false,
  int minutes = 0,
}) => ChatMessage(
  accountId: 'a',
  gid: 'g$id',
  chatGid: 'c',
  serverId: id,
  senderId: sender,
  sentAt: _t0.add(Duration(minutes: minutes)),
  content: emoji == null
      ? const MessageContent.text('hi')
      : MessageContent.emoji(emoji),
  isMine: mine,
  replyToId: replyTo,
  deleted: deleted,
);

void main() {
  group('a reaction is an emoji reply', () {
    test('only when it answers a message with nothing but an emoji', () {
      expect(_msg(2, replyTo: 1, emoji: '👍').isReaction, isTrue);
      expect(_msg(2, emoji: '👍').isReaction, isFalse, reason: 'not a reply');
      expect(_msg(2, replyTo: 1).isReaction, isFalse, reason: 'text reply');
    });
  });

  group('BuildReactions', () {
    const build = BuildReactions();

    test('gathers one entry per emoji under the message it answers', () {
      final map = build([
        _msg(10, replyTo: 1, emoji: '👍', sender: 5, minutes: 1),
        _msg(11, replyTo: 1, emoji: '❤️', sender: 6, minutes: 2),
        _msg(12, replyTo: 1, emoji: '👍', sender: 6, minutes: 3),
        _msg(13, replyTo: 2, emoji: '👍', sender: 5, minutes: 4),
        _msg(14, replyTo: 1, sender: 5), // a plain reply
      ]);
      expect([for (final r in map[1]!) r.emoji], ['👍', '❤️']);
      expect(
        [for (final r in map[1]!) r.userIds.toList()],
        [
          [5, 6],
          [6],
        ],
      );
      expect(map[2]!.single.count, 1);
    });

    test('a failed reaction was never made; a repeated one is the newest', () {
      final failed = _msg(
        10,
        replyTo: 1,
        emoji: '👍',
        sender: 5,
      ).copyWith(sendState: SendState.failed);
      expect(build([failed]), isEmpty);
      final map = build([
        _msg(11, replyTo: 1, emoji: '❤️', sender: 9, mine: true),
        _msg(12, replyTo: 1, emoji: '❤️', sender: 9, mine: true, minutes: 10),
      ]);
      expect(map[1]!.single.count, 1);
      expect(map[1]!.single.mine!.serverId, 12);
    });

    test('drops retracted reactions and counts one person once', () {
      final map = build([
        _msg(10, replyTo: 1, emoji: '👍', sender: 5, deleted: true),
        _msg(11, replyTo: 1, emoji: '👍', sender: 6, minutes: 1),
        _msg(12, replyTo: 1, emoji: '👍', sender: 6, minutes: 2),
      ]);
      expect(map[1]!.single.userIds, [6]);
    });

    test('remembers which one is the user\'s own', () {
      final map = build([
        _msg(10, replyTo: 1, emoji: '👍', sender: 5),
        _msg(11, replyTo: 1, emoji: '👍', sender: 9, mine: true, minutes: 1),
      ]);
      expect(map[1]!.single.mine?.serverId, 11);
    });
  });

  test('reactions are no part of a thread', () {
    final replies = [
      _msg(10, replyTo: 1, emoji: '👍', minutes: 1),
      _msg(11, replyTo: 1, minutes: 2),
    ];
    const threads = BuildReplyThread();
    expect(threads.countsByRoot(replies), {1: 1});
    expect(threads.summariesByRoot(replies)[1]!.count, 1);
    expect(threads(1, replies).replies.map((r) => r.serverId), [11]);
  });

  test('a reaction never raises a notification', () {
    const notify = ShouldNotifyChatMessage();
    expect(
      notify(
        _msg(10, replyTo: 1, emoji: '👍'),
        enabled: true,
        appFocused: false,
        visibleChat: null,
      ),
      isFalse,
    );
  });

  group('with reactions off', () {
    test('an emoji reply is part of its thread like any reply', () {
      final replies = [
        _msg(10, replyTo: 1, emoji: '👍', minutes: 1),
        _msg(11, replyTo: 1, minutes: 2),
      ];
      const threads = BuildReplyThread();
      expect(threads.countsByRoot(replies, reactions: false), {1: 2});
      expect(threads.summariesByRoot(replies, reactions: false)[1]!.count, 2);
      expect(
        threads(1, replies, reactions: false).replies.map((r) => r.serverId),
        [10, 11],
      );
    });

    test('an emoji reply raises a notification like any message', () {
      expect(
        const ShouldNotifyChatMessage()(
          _msg(10, replyTo: 1, emoji: '👍'),
          enabled: true,
          appFocused: false,
          visibleChat: null,
          reactions: false,
        ),
        isTrue,
      );
    });
  });

  group('ToggleReaction', () {
    late _Repo repo;
    late ToggleReaction toggle;
    final target = _msg(1);

    setUp(() {
      repo = _Repo();
      toggle = ToggleReaction(
        repo,
        now: () => _t0.add(const Duration(minutes: 1)),
      );
      when(
        () => repo.sendEmoji(
          any(),
          any(),
          any(),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => repo.retract(any(), any()),
      ).thenAnswer((_) async => const Ok(null));
    });

    test('reacts with the emoji as a reply to the message', () async {
      final result = await toggle(target, '👍', reactions: const []);
      expect(result, isA<Ok<void>>());
      verify(
        () => repo.sendEmoji('a', 'c', ':thumbsup:', replyToId: 1),
      ).called(1);
    });

    test('takes the user\'s own reaction back by retracting it', () async {
      final reactions = const BuildReactions()([
        _msg(10, replyTo: 1, emoji: '👍', sender: 9, mine: true),
      ])[1]!;
      expect(toggle.canRemove(reactions.single), isTrue);
      await toggle(target, '👍', reactions: reactions);
      verify(() => repo.retract('a', 'g10')).called(1);
      verifyNever(
        () => repo.sendEmoji(
          any(),
          any(),
          any(),
          replyToId: any(named: 'replyToId'),
        ),
      );
    });

    test('cannot take it back after the retract window', () async {
      final late = ToggleReaction(
        repo,
        now: () => _t0.add(const Duration(minutes: 5)),
      );
      final reactions = const BuildReactions()([
        _msg(10, replyTo: 1, emoji: '👍', sender: 9, mine: true),
      ])[1]!;
      expect(late.canRemove(reactions.single), isFalse);
      final result = await late(target, '👍', reactions: reactions);
      expect(
        result,
        isA<Err<void>>().having(
          (e) => e.failure,
          'failure',
          isA<ExpiredFailure>(),
        ),
      );
    });

    test(
      'a tap while its own reaction is still sending does nothing',
      () async {
        final sending = _msg(
          10,
          replyTo: 1,
          emoji: '👍',
          sender: 9,
          mine: true,
        ).copyWith(serverId: null, sendState: SendState.pending);
        final reactions = const BuildReactions()([sending])[1]!;
        expect(
          await toggle(target, '👍', reactions: reactions),
          isA<Ok<void>>(),
        );
        verifyNever(() => repo.retract(any(), any()));
        verifyNever(
          () => repo.sendEmoji(
            any(),
            any(),
            any(),
            replyToId: any(named: 'replyToId'),
          ),
        );
      },
    );

    test('does not react to a message the server has not stored', () async {
      final pending = _msg(1).copyWith(serverId: null);
      expect(
        await toggle(pending, '👍', reactions: const []),
        isA<Err<void>>(),
      );
    });
  });
}

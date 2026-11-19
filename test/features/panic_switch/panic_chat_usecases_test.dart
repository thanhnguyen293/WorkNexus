import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/panic_conversation.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/panic_member.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/panic_switch_config.dart';
import 'package:work_nexus/features/panic_switch/domain/panic_switch_constants.dart';
import 'package:work_nexus/features/panic_switch/domain/repositories/panic_chat_gateway.dart';
import 'package:work_nexus/features/panic_switch/domain/repositories/panic_sticker_source.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/list_panic_chats.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/load_panic_group_members.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/pick_default_panic_group.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/send_panic_sticker.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/should_send_panic.dart';
import 'package:work_nexus/features/panic_switch/domain/value_objects/panic_trigger.dart';

class _MockChats extends Mock implements PanicChatGateway {}

class _MockSticker extends Mock implements PanicStickerSource {}

PanicConversation _chat(String gid, String name, PanicChatKind kind) =>
    PanicConversation(gid: gid, kind: kind, name: name);

PanicMember _user(int id, String name) =>
    PanicMember(userId: id, account: 'u$id', realname: name);

void main() {
  late _MockChats chats;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() => chats = _MockChats());

  group('SendPanicSticker', () {
    test('sends the sticker bytes under the reserved name', () async {
      final sticker = _MockSticker();
      final bytes = Uint8List.fromList([1, 2]);
      when(sticker.bytes).thenAnswer((_) async => Ok(bytes));
      when(
        () => chats.sendFile(
          any(),
          any(),
          name: any(named: 'name'),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      final result = await SendPanicSticker(chats, sticker)(
        trigger: PanicTrigger.release,
        accountId: 'a1',
        chatGid: 'g1',
      );

      expect(result.isOk, isTrue);
      verify(
        () => chats.sendFile(
          'a1',
          'g1',
          name: PanicSwitchConstants.stickerFileName,
          bytes: bytes,
          mimeType: 'image/png',
        ),
      ).called(1);
    });

    test('returns the failure when the sticker cannot be loaded', () async {
      final sticker = _MockSticker();
      when(
        sticker.bytes,
      ).thenAnswer((_) async => const Err(StorageFailure('missing')));

      final result = await SendPanicSticker(chats, sticker)(
        trigger: PanicTrigger.release,
        accountId: 'a1',
        chatGid: 'g1',
      );

      expect(result.failureOrNull, isA<StorageFailure>());
    });
  });

  test('PickDefaultPanicGroup finds the team group by name', () {
    const pick = PickDefaultPanicGroup();
    expect(
      pick([
        _chat('dm', 'VN Mobile Tester', PanicChatKind.direct),
        _chat('g2', ' vn mobile tester ', PanicChatKind.group),
      ]),
      'g2',
    );
    expect(pick([_chat('g3', 'VN Mobile+Tester', PanicChatKind.group)]), 'g3');
    expect(pick([_chat('g1', 'Other', PanicChatKind.group)]), isNull);
  });

  test('ShouldSendPanic needs a group and respects the debounce', () {
    const should = ShouldSendPanic();
    final now = DateTime(2026, 11, 18);
    const config = PanicSwitchConfig(chatGid: 'g1');
    const r = PanicTrigger.release;
    const d = PanicTrigger.demo;
    expect(
      should(trigger: r, config: const PanicSwitchConfig(), now: now),
      isFalse,
    );
    expect(should(trigger: r, config: config, now: now), isTrue);
    // The demo needs demo mode and its own chat.
    expect(should(trigger: d, config: config, now: now), isFalse);
    expect(
      should(trigger: d, config: config.copyWith(demoMode: true), now: now),
      isFalse,
    );
    expect(
      should(
        trigger: d,
        config: config.copyWith(demoMode: true, demoChatGid: 'dm'),
        now: now,
      ),
      isTrue,
    );
    expect(
      should(
        trigger: r,
        config: config,
        now: now,
        lastSentAt: now.subtract(const Duration(seconds: 30)),
      ),
      isFalse,
    );
  });

  test('ListPanicChats offers yourself, then groups and direct chats', () {
    final chats = const ListPanicChats()(
      [
        _chat('g2', 'beta', PanicChatKind.group),
        const PanicConversation(
          gid: 'dm',
          kind: PanicChatKind.direct,
          name: '',
          peerUserId: 2,
        ),
        _chat('bot', 'Bot', PanicChatKind.other),
        const PanicConversation(
          gid: 'cloud',
          kind: PanicChatKind.direct,
          name: '',
          peerUserId: 1,
          isSelf: true,
        ),
        _chat('g1', 'Alpha', PanicChatKind.group),
      ],
      {1: _user(1, 'Me'), 2: _user(2, 'Zoe')},
      selfTitle: 'Myself',
    );

    expect(chats.map((c) => (c.chat.gid, c.title)), [
      ('cloud', 'Myself'),
      ('g1', 'Alpha'),
      ('g2', 'beta'),
      ('dm', 'Zoe'),
    ]);
  });

  test('LoadPanicGroupMembers names the members, without the user', () async {
    when(() => chats.watchUsers('a1')).thenAnswer(
      (_) => Stream.value([_user(1, 'Me'), _user(2, 'Zoe'), _user(3, 'An')]),
    );
    when(() => chats.watchSelfUserId('a1')).thenAnswer((_) => Stream.value(1));
    when(
      () => chats.members('a1', 'g1'),
    ).thenAnswer((_) async => const Ok([1, 2, 3, 9]));

    final result = await LoadPanicGroupMembers(chats)(
      accountId: 'a1',
      chatGid: 'g1',
    );

    expect(result.valueOrNull?.map((u) => u.userId), [3, 2]);
  });
}

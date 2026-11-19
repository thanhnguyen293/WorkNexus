import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/panic_switch_config.dart';
import 'package:work_nexus/features/panic_switch/domain/panic_switch_constants.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/should_trigger_panic.dart';
import 'package:work_nexus/features/panic_switch/domain/value_objects/panic_trigger.dart';

void main() {
  const useCase = ShouldTriggerPanic();
  final now = DateTime(2026, 11, 18, 10);
  const config = PanicSwitchConfig(
    chatGid: 'g1',
    anySender: false,
    allowedSenderIds: [7],
  );

  ChatMessage message({
    String chatGid = 'g1',
    int senderId = 7,
    bool isMine = false,
    String name = PanicSwitchConstants.stickerFileName,
    DateTime? sentAt,
    MessageContent? content,
  }) => ChatMessage(
    accountId: 'a1',
    gid: 'm1',
    chatGid: chatGid,
    senderId: senderId,
    sentAt: sentAt ?? now,
    isMine: isMine,
    content:
        content ??
        MessageContent.image(fileId: 1, name: name, size: 10, time: 0),
  );

  bool run(
    ChatMessage m, {
    PanicSwitchConfig c = config,
    DateTime? last,
    PanicTrigger trigger = PanicTrigger.release,
  }) => useCase(
    trigger: trigger,
    message: m,
    config: c,
    accountId: 'a1',
    now: now,
    lastTriggeredAt: last,
  );

  test('fires for the sticker from an allowed sender in the group', () {
    expect(run(message()), isTrue);
  });

  test('matches the file name in any case', () {
    expect(run(message(name: 'WorkNexus-ThayVo-v1.PNG')), isTrue);
  });

  test('ignores other groups, senders, own messages and other images', () {
    expect(run(message(chatGid: 'g2')), isFalse);
    expect(run(message(senderId: 8)), isFalse);
    expect(run(message(isMine: true)), isFalse);
    expect(run(message(name: 'cat.png')), isFalse);
    expect(
      run(
        message(content: const MessageContent.text('worknexus-thayvo-v1.png')),
      ),
      isFalse,
    );
  });

  test('ignores stale messages but tolerates a little clock skew', () {
    expect(
      run(message(sentAt: now.subtract(const Duration(seconds: 31)))),
      isFalse,
    );
    expect(run(message(sentAt: now.add(const Duration(seconds: 5)))), isTrue);
  });

  test('respects the debounce window', () {
    expect(
      run(message(), last: now.subtract(const Duration(seconds: 59))),
      isFalse,
    );
    expect(
      run(message(), last: now.subtract(const Duration(seconds: 60))),
      isTrue,
    );
  });

  test('demo mode adds the demo trigger; the team group keeps working', () {
    final demo = config.copyWith(demoMode: true, demoChatGid: 'dm');
    const d = PanicTrigger.demo;
    final demoSticker = message(
      chatGid: 'dm',
      senderId: 42,
      name: PanicSwitchConstants.demoStickerFileName,
    );
    // The release trigger is unchanged by demo mode.
    expect(run(message(), c: demo), isTrue);
    // The demo sticker in the demo chat, from anyone.
    expect(run(demoSticker, c: demo, trigger: d), isTrue);
    // Each sticker only sets off its own trigger, in its own chat.
    expect(
      run(
        message(chatGid: 'dm'),
        c: demo,
        trigger: d,
      ),
      isFalse,
    );
    expect(run(demoSticker, c: demo), isFalse);
    expect(
      run(
        message(name: PanicSwitchConstants.demoStickerFileName),
        c: demo,
        trigger: d,
      ),
      isFalse,
    );
    // Off without demo mode.
    expect(
      run(
        demoSticker,
        c: config.copyWith(demoChatGid: 'dm'),
        trigger: d,
      ),
      isFalse,
    );
  });

  test('tells the two stickers apart', () {
    MessageContent image(String name) =>
        MessageContent.image(fileId: 1, name: name, size: 1, time: 0);
    expect(
      ShouldTriggerPanic.triggerOf(image(PanicSwitchConstants.stickerFileName)),
      PanicTrigger.release,
    );
    expect(
      ShouldTriggerPanic.triggerOf(
        image(PanicSwitchConstants.demoStickerFileName),
      ),
      PanicTrigger.demo,
    );
    expect(ShouldTriggerPanic.triggerOf(image('cat.png')), isNull);
  });

  test('lets anyone in the chat set it off by default', () {
    const anyone = PanicSwitchConfig(chatGid: 'g1');
    expect(run(message(senderId: 42), c: anyone), isTrue);
    expect(run(message(senderId: 42, isMine: true), c: anyone), isFalse);
  });

  test('does nothing when disabled or with nobody allowed', () {
    expect(run(message(), c: config.copyWith(enabled: false)), isFalse);
    expect(run(message(), c: config.copyWith(allowedSenderIds: [])), isFalse);
  });
}

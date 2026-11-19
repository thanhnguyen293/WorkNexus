import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/panic_switch_config.dart';
import 'package:work_nexus/features/panic_switch/domain/panic_switch_constants.dart';
import 'package:work_nexus/features/panic_switch/domain/repositories/panic_overlay.dart';
import 'package:work_nexus/features/panic_switch/domain/repositories/panic_sticker_source.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/run_panic_switch.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/send_panic_sticker.dart';
import 'package:work_nexus/features/panic_switch/domain/value_objects/panic_trigger.dart';
import 'package:work_nexus/features/panic_switch/presentation/providers/panic_switch_runtime.dart';

class _MockRun extends Mock implements RunPanicSwitch {}

class _MockSend extends Mock implements SendPanicSticker {}

class _MockOverlay extends Mock implements PanicOverlay {}

class _MockSticker extends Mock implements PanicStickerSource {}

void main() {
  const account = Account(
    id: 'a1',
    workspaceId: 'w',
    providerType: ProviderType.zentao,
    handle: 'me',
  );
  const config = PanicSwitchConfig(chatGid: 'g1', allowedSenderIds: [7]);
  late _MockRun run;
  late _MockSend send;
  late DateTime now;
  late PanicSwitchRuntime runtime;

  setUpAll(() {
    registerFallbackValue(const PanicSwitchConfig());
    registerFallbackValue(PanicTrigger.release);
  });

  setUp(() {
    run = _MockRun();
    send = _MockSend();
    now = DateTime(2026, 11, 18, 10);
    when(() => run(any())).thenAnswer((_) async => const Ok(null));
    when(
      () => send(
        trigger: any(named: 'trigger'),
        accountId: any(named: 'accountId'),
        chatGid: any(named: 'chatGid'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    runtime = PanicSwitchRuntime(
      account: () => account,
      config: () => config,
      run: run,
      send: send,
      overlay: _MockOverlay(),
      sticker: _MockSticker(),
      incoming: const Stream.empty(),
      clock: () => now,
    );
  });

  ChatMessage sticker({
    String chatGid = 'g1',
    String name = PanicSwitchConstants.stickerFileName,
  }) => ChatMessage(
    accountId: 'a1',
    gid: 'm',
    chatGid: chatGid,
    senderId: 7,
    sentAt: now,
    isMine: false,
    content: MessageContent.image(fileId: 1, name: name, size: 1, time: 0),
  );

  PanicSwitchRuntime runtimeFor(PanicSwitchConfig c) => PanicSwitchRuntime(
    account: () => account,
    config: () => c,
    run: run,
    send: send,
    overlay: _MockOverlay(),
    sticker: _MockSticker(),
    incoming: const Stream.empty(),
    clock: () => now,
  );

  test('switches once per debounce window', () async {
    await runtime.onIncoming(sticker());
    now = now.add(const Duration(seconds: 10));
    await runtime.onIncoming(sticker());
    verify(() => run(config)).called(1);

    now = now.add(const Duration(seconds: 60));
    await runtime.onIncoming(sticker());
    verify(() => run(config)).called(1);
  });

  test('sends the sticker to the group once per debounce window', () async {
    await runtime.onOverlayTriggered(PanicTrigger.release);
    await runtime.onOverlayTriggered(PanicTrigger.release);
    verify(
      () => send(trigger: PanicTrigger.release, accountId: 'a1', chatGid: 'g1'),
    ).called(1);
  });

  test('demo and release run side by side, each debounced', () async {
    final demo = config.copyWith(demoMode: true, demoChatGid: 'dm');
    final r = runtimeFor(demo);

    await r.onOverlayTriggered(PanicTrigger.release);
    await r.onOverlayTriggered(PanicTrigger.demo);
    await r.onOverlayTriggered(PanicTrigger.demo);
    verify(
      () => send(trigger: PanicTrigger.release, accountId: 'a1', chatGid: 'g1'),
    ).called(1);
    verify(
      () => send(trigger: PanicTrigger.demo, accountId: 'a1', chatGid: 'dm'),
    ).called(1);

    await r.onIncoming(sticker());
    await r.onIncoming(
      sticker(chatGid: 'dm', name: PanicSwitchConstants.demoStickerFileName),
    );
    verify(() => run(demo)).called(2);
  });

  test('the demo trigger does nothing without demo mode', () async {
    await runtime.onOverlayTriggered(PanicTrigger.demo);
    verifyNever(
      () => send(
        trigger: any(named: 'trigger'),
        accountId: any(named: 'accountId'),
        chatGid: any(named: 'chatGid'),
      ),
    );
  });

  test('sent to yourself, also switches apps here', () async {
    const self = PanicSwitchConfig(
      demoMode: true,
      demoChatGid: 'cloud',
      demoChatIsSelf: true,
    );
    final r = runtimeFor(self);

    when(
      () => send(
        trigger: any(named: 'trigger'),
        accountId: any(named: 'accountId'),
        chatGid: any(named: 'chatGid'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure('server down')));

    final result = await r.onOverlayTriggered(PanicTrigger.demo);

    // Switched even though the chat server is down; the send failure is
    // still reported.
    verify(() => run(self)).called(1);
    verify(
      () => send(trigger: PanicTrigger.demo, accountId: 'a1', chatGid: 'cloud'),
    ).called(1);
    expect(result.failureOrNull, isA<NetworkFailure>());
  });

  test('runNow switches without any chat', () async {
    await runtime.runNow();
    verify(() => run(config)).called(1);
    verifyNever(
      () => send(
        trigger: any(named: 'trigger'),
        accountId: any(named: 'accountId'),
        chatGid: any(named: 'chatGid'),
      ),
    );
  });

  test('shows the overlay with the sticker image', () async {
    final overlay = _MockOverlay();
    final source = _MockSticker();
    final image = Uint8List.fromList([1, 2, 3]);
    when(source.bytes).thenAnswer((_) async => Ok(image));
    when(() => overlay.show(image)).thenAnswer((_) async => const Ok(null));
    final r = PanicSwitchRuntime(
      account: () => account,
      config: () => config,
      run: run,
      send: send,
      overlay: overlay,
      sticker: source,
      incoming: const Stream.empty(),
    );

    expect((await r.showOverlay(true)).isOk, isTrue);
    verify(() => overlay.show(image)).called(1);
  });
}

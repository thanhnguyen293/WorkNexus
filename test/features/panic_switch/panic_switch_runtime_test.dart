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

  setUpAll(() => registerFallbackValue(const PanicSwitchConfig()));

  setUp(() {
    run = _MockRun();
    send = _MockSend();
    now = DateTime(2026, 11, 18, 10);
    when(() => run(any())).thenAnswer((_) async => const Ok(null));
    when(
      () => send(
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

  ChatMessage sticker() => ChatMessage(
    accountId: 'a1',
    gid: 'm',
    chatGid: 'g1',
    senderId: 7,
    sentAt: now,
    isMine: false,
    content: const MessageContent.image(
      fileId: 1,
      name: PanicSwitchConstants.stickerFileName,
      size: 1,
      time: 0,
    ),
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
    await runtime.onOverlayTriggered();
    await runtime.onOverlayTriggered();
    verify(() => send(accountId: 'a1', chatGid: 'g1')).called(1);
  });

  test('sent to yourself, also switches apps here', () async {
    const self = PanicSwitchConfig(
      testMode: true,
      testSendChatGid: 'cloud',
      testSendToSelf: true,
    );
    final r = PanicSwitchRuntime(
      account: () => account,
      config: () => self,
      run: run,
      send: send,
      overlay: _MockOverlay(),
      sticker: _MockSticker(),
      incoming: const Stream.empty(),
      clock: () => now,
    );

    when(
      () => send(
        accountId: any(named: 'accountId'),
        chatGid: any(named: 'chatGid'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure('server down')));

    final result = await r.onOverlayTriggered();

    // Switched even though the chat server is down; the send failure is
    // still reported.
    verify(() => run(self)).called(1);
    verify(() => send(accountId: 'a1', chatGid: 'cloud')).called(1);
    expect(result.failureOrNull, isA<NetworkFailure>());
  });

  test('runNow switches without any chat', () async {
    await runtime.runNow();
    verify(() => run(config)).called(1);
    verifyNever(
      () => send(
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

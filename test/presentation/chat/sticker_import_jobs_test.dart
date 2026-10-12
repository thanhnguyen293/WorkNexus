import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/remote_sticker_set.dart';
import 'package:work_nexus/features/chat/domain/repositories/sticker_pack_source.dart';
import 'package:work_nexus/features/chat/domain/repositories/sticker_repository.dart';
import 'package:work_nexus/features/chat/presentation/providers/sticker_import_jobs.dart';
import 'package:work_nexus/features/chat/presentation/providers/sticker_providers.dart';

class _Source extends Mock implements StickerPackSource {}

class _Converter extends Mock implements StickerConverter {}

class _Stickers extends Mock implements StickerRepository {}

class _Tokens implements TelegramTokenStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}
}

void main() {
  late _Source source;
  late ProviderContainer container;

  /// Holds back each file until the test lets it through.
  late Completer<void> gate;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    source = _Source();
    final converter = _Converter();
    final stickers = _Stickers();
    gate = Completer<void>();
    when(() => source.stickerSet('Cats', token: 'T')).thenAnswer(
      (_) async => const Ok(
        RemoteStickerSet(
          name: 'Cats',
          title: 'Cats!',
          stickers: [
            RemoteSticker(fileId: 'a', kind: RemoteStickerKind.still),
            RemoteSticker(fileId: 'b', kind: RemoteStickerKind.still),
          ],
        ),
      ),
    );
    when(() => source.file(any(), token: 'T')).thenAnswer((_) async {
      await gate.future;
      return Ok(Uint8List.fromList([1]));
    });
    when(() => converter.stillToWebp(any())).thenAnswer(
      (call) async => Ok(call.positionalArguments.single as Uint8List),
    );
    when(
      () => stickers.addPack(
        any(),
        title: any(named: 'title'),
        stickers: any(named: 'stickers'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    container = ProviderContainer(
      overrides: [
        stickerPackSourceProvider.overrideWithValue(source),
        stickerConverterProvider.overrideWithValue(converter),
        stickerRepositoryProvider.overrideWithValue(stickers),
        telegramTokenStoreProvider.overrideWithValue(_Tokens()),
      ],
    );
    addTearDown(container.dispose);
  });

  StickerImportsController jobs() =>
      container.read(stickerImportsProvider.notifier);

  test(
    'start resolves once listed; the import finishes in the background',
    () async {
      final started = await jobs().start('Cats', token: 'T');

      expect(started.valueOrNull, 'Cats!');
      final running = container.read(stickerImportsProvider).single;
      expect(
        (running.title, running.total, running.finished),
        ('Cats!', 2, false),
      );

      gate.complete();
      await pumpEventQueue();

      final done = container.read(stickerImportsProvider).single;
      expect(done.done, 2);
      expect(done.result?.added, 2);
      expect(done.finished, isTrue);
    },
  );

  test(
    'starting a set already being imported does not start it twice',
    () async {
      await jobs().start('Cats', token: 'T');
      await jobs().start('https://t.me/addstickers/Cats', token: 'T');

      expect(container.read(stickerImportsProvider), hasLength(1));
      verify(() => source.stickerSet('Cats', token: 'T')).called(1);
    },
  );

  test('a bad token fails start itself, leaving no job', () async {
    when(
      () => source.stickerSet('Cats', token: 'BAD'),
    ).thenAnswer((_) async => const Err(AuthFailure('refused')));

    final started = await jobs().start('Cats', token: 'BAD');

    expect(started.failureOrNull, isA<AuthFailure>());
    expect(container.read(stickerImportsProvider), isEmpty);
  });

  test('a finished job is forgotten once shown', () async {
    gate.complete();
    await jobs().start('Cats', token: 'T');
    await pumpEventQueue();

    jobs().dismiss('Cats');

    expect(container.read(stickerImportsProvider), isEmpty);
  });
}

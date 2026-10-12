import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/remote_sticker_set.dart';
import 'package:work_nexus/features/chat/domain/repositories/sticker_pack_source.dart';
import 'package:work_nexus/features/chat/domain/repositories/sticker_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/import_sticker_pack.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_sticker_pack_link.dart';

class _Source extends Mock implements StickerPackSource {}

class _Converter extends Mock implements StickerConverter {}

class _Stickers extends Mock implements StickerRepository {}

Uint8List _bytes(int b) => Uint8List.fromList([b]);

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));

  group('ParseStickerPackLink', () {
    const parse = ParseStickerPackLink();

    test('reads the set name from a link or takes a bare name', () {
      expect(parse('https://t.me/addstickers/Peepo_Pepe'), 'Peepo_Pepe');
      expect(parse('t.me/addstickers/Peepo_Pepe?x=1'), 'Peepo_Pepe');
      expect(parse(' www.t.me/addstickers/Cats/ '), 'Cats');
      expect(parse('Peepo_Pepe'), 'Peepo_Pepe');
    });

    test('anything else is not a set', () {
      expect(parse('https://example.com/addstickers/Cats'), isNull);
      expect(parse('t.me/joinchat/abc'), isNull);
      expect(parse('two words'), isNull);
      expect(parse(''), isNull);
    });
  });

  group('ImportStickerPack', () {
    late _Source source;
    late _Converter converter;
    late _Stickers stickers;
    late ImportStickerPack import;
    List<StickerFile> kept = const [];

    setUp(() {
      source = _Source();
      converter = _Converter();
      stickers = _Stickers();
      import = ImportStickerPack(source, converter, stickers);
      // Scaling a still marks it, so a test can tell it was scaled.
      when(() => converter.stillToWebp(any())).thenAnswer(
        (call) async => Ok(
          Uint8List.fromList([
            100 + (call.positionalArguments.single as Uint8List).single,
          ]),
        ),
      );
      when(
        () => stickers.addPack(
          any(),
          title: any(named: 'title'),
          stickers: any(named: 'stickers'),
        ),
      ).thenAnswer((call) async {
        kept = call.namedArguments[#stickers] as List<StickerFile>;
        return const Ok(null);
      });
    });

    void set(List<RemoteSticker> list) =>
        when(() => source.stickerSet('Cats', token: 't')).thenAnswer(
          (_) async => Ok(
            RemoteStickerSet(name: 'Cats', title: 'Cats!', stickers: list),
          ),
        );

    void file(String id, int byte) => when(
      () => source.file(id, token: 't'),
    ).thenAnswer((_) async => Ok(_bytes(byte)));

    test('keeps stills as they are and converts animations to WebP', () async {
      set(const [
        RemoteSticker(fileId: 'a', kind: RemoteStickerKind.still),
        RemoteSticker(fileId: 'b', kind: RemoteStickerKind.animated),
      ]);
      file('a', 1);
      file('b', 2);
      when(
        () => converter.animatedToWebp(_bytes(2)),
      ).thenAnswer((_) async => Ok(_bytes(22)));
      final progress = <int>[];

      final res = await import(
        'https://t.me/addstickers/Cats',
        token: 't',
        onProgress: (done, _) => progress.add(done),
      );

      expect(res.valueOrNull, (
        pack: 'tg:Cats',
        title: 'Cats!',
        added: 2,
        stills: 0,
        failed: 0,
      ));
      expect(kept.map((f) => f.name), ['001.webp', '002.webp']);
      expect(kept.map((f) => f.bytes.single), [101, 22]);
      expect(progress, [1, 2]);
    });

    test('videos and unconvertible animations fall back to a still', () async {
      set(const [
        RemoteSticker(
          fileId: 'v',
          kind: RemoteStickerKind.video,
          thumbnailFileId: 'vt',
        ),
        RemoteSticker(
          fileId: 'b',
          kind: RemoteStickerKind.animated,
          thumbnailFileId: 'bt',
        ),
        // No still to fall back on: skipped.
        RemoteSticker(fileId: 'w', kind: RemoteStickerKind.video),
      ]);
      file('vt', 3);
      file('b', 2);
      file('bt', 4);
      when(
        () => converter.animatedToWebp(any()),
      ).thenAnswer((_) async => const Err(ParseFailure('bad lottie')));

      final res = await import('Cats', token: 't');

      expect(res.valueOrNull?.added, 2);
      expect(res.valueOrNull?.stills, 2);
      expect(res.valueOrNull?.failed, 1);
      expect(kept.map((f) => f.bytes.single), [103, 104]);
      verifyNever(() => source.file('v', token: any(named: 'token')));
    });

    test('a link that is not a set fails without asking Telegram', () async {
      final res = await import('https://example.com/x', token: 't');

      expect(res.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => source.stickerSet(any(), token: any(named: 'token')));
    });

    test("Telegram's refusal is passed on; nothing is kept", () async {
      when(
        () => source.stickerSet('Cats', token: 't'),
      ).thenAnswer((_) async => const Err(AuthFailure('bad token')));

      final res = await import('Cats', token: 't');

      expect(res.failureOrNull, isA<AuthFailure>());
      verifyNever(
        () => stickers.addPack(
          any(),
          title: any(named: 'title'),
          stickers: any(named: 'stickers'),
        ),
      );
    });

    test('a set none of whose stickers can be fetched fails', () async {
      set(const [RemoteSticker(fileId: 'a', kind: RemoteStickerKind.still)]);
      when(
        () => source.file('a', token: 't'),
      ).thenAnswer((_) async => const Err(NetworkFailure('offline')));

      final res = await import('Cats', token: 't');

      expect(res.failureOrNull, isA<NetworkFailure>());
    });

    test('a still that cannot be scaled is kept as it came', () async {
      set(const [RemoteSticker(fileId: 'a', kind: RemoteStickerKind.still)]);
      file('a', 7);
      when(
        () => converter.stillToWebp(any()),
      ).thenAnswer((_) async => const Err(ParseFailure('unreadable')));

      final res = await import('Cats', token: 't');

      expect(res.valueOrNull?.added, 1);
      expect(kept.single.bytes.single, 7);
    });
  });
}

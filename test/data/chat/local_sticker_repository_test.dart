import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/repositories/local_sticker_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late LocalStickerRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('stickers');
    repo = LocalStickerRepository(
      bundle: rootBundle,
      directory: () async => dir,
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('bundled sets are grouped by folder', () async {
    final all = switch (await repo.stickers()) {
      Ok(:final value) => value,
      Err() => fail('could not list'),
    };
    expect(all, isNotEmpty);
    expect(all.map((s) => s.pack).toSet(), {'PepeAnim', 'Pepe', 'WorkNexus'});
    expect(
      all.every(
        (s) => !s.custom && s.location == 'assets/stickers/${s.pack}/${s.name}',
      ),
      isTrue,
    );
  });

  test("the user's own stickers can be added, read and removed", () async {
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    final added = switch (await repo.add(bytes, name: 'my cat')) {
      Ok(:final value) => value,
      Err() => fail('could not add'),
    };
    expect(added.custom, isTrue);
    expect(added.name, 'my_cat.png');
    final read = await repo.bytes(added);
    expect(read is Ok<Uint8List> ? read.value : null, bytes);

    final all = switch (await repo.stickers()) {
      Ok(:final value) => value,
      Err() => fail('could not list'),
    };
    expect(all.last, added);

    await repo.remove(added);
    expect(File(added.location).existsSync(), isFalse);
  });

  test('bundled stickers cannot be removed', () async {
    final bundled = switch (await repo.stickers()) {
      Ok(:final value) => value.first,
      Err() => fail('could not list'),
    };
    expect(await repo.remove(bundled), isA<Err<void>>());
  });

  test(
    'an imported set is kept as one set, listed after the bundled',
    () async {
      final png = Uint8List.fromList([137, 80, 78, 71]);
      final added = await repo.addPack(
        'tg:Peepo',
        title: 'Peepo Pepe',
        stickers: [
          (name: '001.webp', bytes: png),
          (name: '002.webp', bytes: png),
        ],
      );
      expect(added, isA<Ok<void>>());

      final all = switch (await repo.stickers()) {
        Ok(:final value) => value,
        Err() => fail('could not list'),
      };
      final set = all.where((s) => s.pack == 'tg:Peepo').toList();
      expect(set.map((s) => s.name), ['001.webp', '002.webp']);
      expect(set.every((s) => s.custom && s.packTitle == 'Peepo Pepe'), isTrue);
      // Not mixed into the user's own stickers.
      expect(all.where((s) => s.custom && s.pack.isEmpty), isEmpty);
      expect(await repo.bytes(set.first), isA<Ok<Uint8List>>());
    },
  );

  test('importing a set again replaces it; removing it deletes it', () async {
    final png = Uint8List.fromList([137, 80, 78, 71]);
    await repo.addPack(
      'tg:Peepo',
      title: 'Old',
      stickers: [
        (name: '001.webp', bytes: png),
        (name: '002.webp', bytes: png),
      ],
    );
    await repo.addPack(
      'tg:Peepo',
      title: 'New',
      stickers: [(name: '001.webp', bytes: png)],
    );
    var all = (await repo.stickers()).valueOrNull ?? const [];
    final kept = all.where((s) => s.pack == 'tg:Peepo').toList();
    expect(kept, hasLength(1));
    expect(kept.single.packTitle, 'New');

    await repo.removePack('tg:Peepo');
    all = (await repo.stickers()).valueOrNull ?? const [];
    expect(all.where((s) => s.pack == 'tg:Peepo'), isEmpty);
  });

  test('the last set picked from is remembered, and is no sticker', () async {
    expect((await repo.lastPack()).valueOrNull, isNull);

    await repo.rememberPack('tg:Peepo');

    expect((await repo.lastPack()).valueOrNull, 'tg:Peepo');
    final all = (await repo.stickers()).valueOrNull ?? const [];
    expect(all.where((s) => s.custom), isEmpty);
  });
}

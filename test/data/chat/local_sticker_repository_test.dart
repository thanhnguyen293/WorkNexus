import 'dart:io';

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
    expect(all.every((s) => s.pack == 'WorkNexus' && !s.custom), isTrue);
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
}

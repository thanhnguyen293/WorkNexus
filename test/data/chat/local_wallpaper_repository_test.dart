import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/repositories/local_wallpaper_repository.dart';

void main() {
  late Directory dir;
  late LocalWallpaperRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wallpapers');
    repo = LocalWallpaperRepository(directory: () async => dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('added images are listed newest first and can be removed', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final first = switch (await repo.add(bytes, name: 'beach.jpg')) {
      Ok(:final value) => value,
      Err() => fail('could not add'),
    };
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = switch (await repo.add(bytes, name: 'my city')) {
      Ok(:final value) => value,
      Err() => fail('could not add'),
    };
    expect(second, endsWith('my_city.png'));
    expect(await repo.wallpapers(), isA<Ok<List<String>>>());
    final listed = (await repo.wallpapers()) as Ok<List<String>>;
    expect(listed.value, [second, first]);

    await repo.remove(first);
    expect(File(first).existsSync(), isFalse);
  });

  test('files outside its folder are never removed', () async {
    final other = File('${Directory.systemTemp.path}/not-a-wallpaper.png')
      ..writeAsBytesSync([1]);
    addTearDown(other.deleteSync);
    expect(await repo.remove(other.path), isA<Err<void>>());
    expect(other.existsSync(), isTrue);
  });

  test('an empty image is refused', () async {
    expect(await repo.add(Uint8List(0), name: 'x.png'), isA<Err<String>>());
  });
}

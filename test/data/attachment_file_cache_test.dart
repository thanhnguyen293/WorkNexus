import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/sync/data/attachment_file_cache.dart';

Uint8List _bytes(int length) => Uint8List(length);

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('worknexus_att_test_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('stores bytes and reports the path back via existing()', () async {
    final cache = AttachmentFileCache(root: root);

    expect(await cache.existing('1', 'clip.mp4'), isNull);
    final path = await cache.store('1', 'clip.mp4', _bytes(10));

    expect(await File(path).exists(), isTrue);
    expect(await cache.existing('1', 'clip.mp4'), path);
  });

  test('evicts the oldest files once the byte cap is exceeded', () async {
    final cache = AttachmentFileCache(root: root, maxBytes: 100);

    await cache.store('a', 'a.bin', _bytes(40));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await cache.store('b', 'b.bin', _bytes(40)); // total 80, under cap
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await cache.store('c', 'c.bin', _bytes(40)); // total 120 -> evict oldest

    expect(await cache.existing('a', 'a.bin'), isNull); // oldest, evicted
    expect(await cache.existing('b', 'b.bin'), isNotNull);
    expect(await cache.existing('c', 'c.bin'), isNotNull); // freshly written
  });

  test('purge wipes the whole cache directory', () async {
    final cache = AttachmentFileCache(root: root);
    await cache.store('1', 'clip.mp4', _bytes(10));

    await cache.purge();

    expect(await root.exists(), isFalse);
    expect(await cache.existing('1', 'clip.mp4'), isNull);
  });

  test('purge on an empty/absent cache is a no-op', () async {
    final cache = AttachmentFileCache(root: root);
    await root.delete(recursive: true);

    await cache.purge(); // must not throw

    expect(await cache.existing('1', 'clip.mp4'), isNull);
  });
}

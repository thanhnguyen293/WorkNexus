import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/sync/data/byte_lru_cache.dart';

Uint8List _bytes(int length) => Uint8List(length);

void main() {
  test('stores and returns bytes by key, tracking total size', () {
    final cache = ByteLruCache(maxBytes: 100);

    cache.put('a', _bytes(30));
    cache.put('b', _bytes(20));

    expect(cache.usedBytes, 50);
    expect(cache.get('a')!.lengthInBytes, 30);
    expect(cache.get('b')!.lengthInBytes, 20);
    expect(cache.get('missing'), isNull);
  });

  test('evicts the least-recently-used entry when the cap is exceeded', () {
    final cache = ByteLruCache(maxBytes: 100);

    cache.put('a', _bytes(40));
    cache.put('b', _bytes(40));
    // Touch 'a' so 'b' becomes the least-recently-used.
    cache.get('a');
    // Inserting 40 more (total 120 > 100) must evict 'b', not 'a'.
    cache.put('c', _bytes(40));

    expect(cache.get('a'), isNotNull);
    expect(cache.get('b'), isNull);
    expect(cache.get('c'), isNotNull);
    expect(cache.usedBytes, 80);
  });

  test('re-inserting a key replaces its bytes without double-counting', () {
    final cache = ByteLruCache(maxBytes: 100);

    cache.put('a', _bytes(30));
    cache.put('a', _bytes(50));

    expect(cache.usedBytes, 50);
    expect(cache.get('a')!.lengthInBytes, 50);
  });

  test('does not cache a blob larger than the cap', () {
    final cache = ByteLruCache(maxBytes: 100);

    cache.put('small', _bytes(60));
    cache.put('huge', _bytes(200));

    expect(cache.get('huge'), isNull);
    // The oversized put must not have flushed the existing small entry.
    expect(cache.get('small'), isNotNull);
    expect(cache.usedBytes, 60);
  });

  test('clear drops everything', () {
    final cache = ByteLruCache(maxBytes: 100);
    cache.put('a', _bytes(30));

    cache.clear();

    expect(cache.get('a'), isNull);
    expect(cache.usedBytes, 0);
  });
}

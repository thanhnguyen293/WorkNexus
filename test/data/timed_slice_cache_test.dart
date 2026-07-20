import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/sync/data/timed_slice_cache.dart';

void main() {
  test('returns cached value until the ttl expires', () async {
    var now = DateTime(2026, 7, 20, 10);
    var calls = 0;
    final cache = TimedSliceCache<List<String>>(
      ttl: const Duration(minutes: 15),
      now: () => now,
    );

    Future<List<String>> load() async {
      calls++;
      return ['call-$calls'];
    }

    expect(await cache.get('zt:8:unclosed', load), ['call-1']);

    now = now.add(const Duration(minutes: 14, seconds: 59));
    expect(await cache.get('zt:8:unclosed', load), ['call-1']);
    expect(calls, 1);

    now = now.add(const Duration(seconds: 1));
    expect(await cache.get('zt:8:unclosed', load), ['call-2']);
    expect(calls, 2);
  });

  test('keeps independent cache entries per key', () async {
    var calls = 0;
    final cache = TimedSliceCache<int>(
      ttl: const Duration(minutes: 15),
      now: () => DateTime(2026, 7, 20, 10),
    );

    Future<int> load() async => ++calls;

    expect(await cache.get('zt:8:unclosed', load), 1);
    expect(await cache.get('zt:8:all', load), 2);
    expect(await cache.get('zt:8:unclosed', load), 1);
    expect(await cache.get('zt:8:all', load), 2);
    expect(calls, 2);
  });
}

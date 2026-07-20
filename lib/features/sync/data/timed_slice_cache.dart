class TimedSliceCache<T> {
  TimedSliceCache({required this.ttl, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Duration ttl;
  final DateTime Function() _now;
  final Map<String, _TimedCacheEntry<T>> _entries = {};

  Future<T> get(String key, Future<T> Function() load) async {
    final current = _now();
    final cached = _entries[key];
    if (cached != null && current.difference(cached.cachedAt) < ttl) {
      return cached.value;
    }
    final value = await load();
    _entries[key] = _TimedCacheEntry(value: value, cachedAt: current);
    return value;
  }

  void invalidate(String key) => _entries.remove(key);

  void clear() => _entries.clear();
}

class _TimedCacheEntry<T> {
  const _TimedCacheEntry({required this.value, required this.cachedAt});

  final T value;
  final DateTime cachedAt;
}

/// Shares one in-flight async load per key: callers asking for a key that is
/// already loading get the same future instead of starting another request.
/// The entry is dropped once the load completes (with a value or an error), so
/// a later call always loads afresh — this deduplicates, it does not cache.
class InFlight<K, V> {
  final _pending = <K, Future<V>>{};

  /// Whether a load for [key] is currently running.
  bool isLoading(K key) => _pending.containsKey(key);

  /// Returns the running load for [key], or starts [load] for it.
  Future<V> run(K key, Future<V> Function() load) =>
      // Block body: whenComplete awaits a returned Future, and `remove` would
      // hand back this very future — it would wait on itself forever.
      _pending[key] ??= load().whenComplete(() {
        _pending.remove(key);
      });
}

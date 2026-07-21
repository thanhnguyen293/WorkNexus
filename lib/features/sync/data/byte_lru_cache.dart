import 'dart:typed_data';

/// An in-memory LRU cache for image bytes, bounded by total retained size.
///
/// Backs [SyncService]'s inline-image cache: successfully fetched image bytes
/// are kept so a detail panel reuses them instead of refetching on every tab
/// switch / rebuild. Bounding the total at [maxBytes] (default 500 MB) is what
/// stops it from growing without limit for the app's whole lifetime.
///
/// Insertion order tracks least→most recently used: a [get] moves the entry to
/// the most-recent end, and inserting past the cap evicts the least-recently
/// used entries until it fits again. A single blob larger than [maxBytes] is
/// not cached — it would flush everything and still not fit.
class ByteLruCache {
  ByteLruCache({this.maxBytes = 500 * 1024 * 1024});

  /// Maximum total bytes retained across all entries.
  final int maxBytes;

  final Map<String, Uint8List> _entries = {};
  int _usedBytes = 0;

  /// Total bytes currently retained.
  int get usedBytes => _usedBytes;

  Uint8List? get(String key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    // Re-insert at the end so it counts as most-recently-used.
    _entries[key] = value;
    return value;
  }

  void put(String key, Uint8List value) {
    final existing = _entries.remove(key);
    if (existing != null) _usedBytes -= existing.lengthInBytes;
    // A blob that can never fit would evict the whole cache for nothing.
    if (value.lengthInBytes > maxBytes) return;
    _entries[key] = value;
    _usedBytes += value.lengthInBytes;
    while (_usedBytes > maxBytes && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      _usedBytes -= _entries.remove(oldest)!.lengthInBytes;
    }
  }

  void clear() {
    _entries.clear();
    _usedBytes = 0;
  }
}

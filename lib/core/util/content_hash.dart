/// Stable, deterministic content hash used to key translation caches and detect
/// when a ticket's source text changed since it was translated. Not
/// cryptographic — just needs to be stable and collision-resistant enough.
String contentHash(String title, String body) =>
    intHash('$title $body').toRadixString(16);

/// Stable non-negative 31-bit hash of a string (h*31+c), matching the design's
/// deterministic hashing used to derive demo dev context.
int intHash(String s) {
  var h = 0;
  for (var i = 0; i < s.length; i++) {
    h = ((h * 31) + s.codeUnitAt(i)) & 0x7fffffff;
  }
  return h;
}

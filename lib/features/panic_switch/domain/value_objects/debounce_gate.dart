/// Whether something last done at [last] may happen again at [now], given it
/// may happen at most once per [window].
bool debounceAllows({
  required DateTime? last,
  required DateTime now,
  required Duration window,
}) => last == null || now.difference(last) >= window;

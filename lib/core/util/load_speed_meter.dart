/// How fast something loads, from how many bytes are in at moments in time,
/// averaged over the last [window] so one slow or quick sample doesn't swing
/// it.
class LoadSpeedMeter {
  LoadSpeedMeter({this.window = const Duration(seconds: 3)});

  final Duration window;
  final _samples = <(DateTime, int)>[];

  /// Notes that [bytes] were loaded by [at].
  void add(DateTime at, int bytes) {
    // A seek can restart the buffer lower: a new run, not negative speed.
    if (_samples.isNotEmpty && bytes < _samples.last.$2) _samples.clear();
    _samples.add((at, bytes));
    while (_samples.length > 2 && at.difference(_samples[1].$1) >= window) {
      _samples.removeAt(0);
    }
  }

  /// Bytes per second over the window; null until two samples are apart.
  double? get bytesPerSecond {
    if (_samples.length < 2) return null;
    final (from, fromBytes) = _samples.first;
    final (to, toBytes) = _samples.last;
    final ms = to.difference(from).inMilliseconds;
    if (ms <= 0) return null;
    return (toBytes - fromBytes) * 1000 / ms;
  }
}

/// "m:ss", or "h:mm:ss" for long videos.
String formatVideoTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

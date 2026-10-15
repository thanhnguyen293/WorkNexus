/// The mini apps to keep running, least recently shown first: [live] with
/// [current] moved to the end, apps no longer in [existing] dropped, and the
/// oldest closed while more than [max] remain. [current] is never closed.
List<String> liveMiniApps({
  required List<String> live,
  required String? current,
  required Set<String> existing,
  required int max,
}) {
  final next = [
    for (final id in live)
      if (id != current && existing.contains(id)) id,
    if (current != null && existing.contains(current)) current,
  ];
  final over = next.length - max;
  return over > 0 ? next.sublist(over) : next;
}

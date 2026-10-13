/// One run of a localized sentence: literal [text], or the placeholder at
/// index [slot].
typedef TemplateRun = ({String text, int? slot});

/// Splits a localized message around its placeholders, so each one can render
/// as its own span or widget (a bold name, a branch ref) while translators keep
/// control of the word order. [build] gets one marker per placeholder — in
/// placeholder order — and returns the message built from them.
List<TemplateRun> templateRuns(
  String Function(List<String> marks) build,
  int slots,
) {
  // Private-use code points never occur in real text.
  final marks = [
    for (var i = 0; i < slots; i++) String.fromCharCode(0xE000 + i),
  ];
  final set = marks.join();
  return [
    for (final m in RegExp('[$set]|[^$set]+').allMatches(build(marks)))
      (
        text: m.group(0)!,
        slot: marks.contains(m.group(0)) ? marks.indexOf(m.group(0)!) : null,
      ),
  ];
}

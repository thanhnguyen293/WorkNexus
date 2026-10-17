/// How far back message search looks, counted back from now.
enum ChatSearchPeriod {
  all(null),
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  quarter(Duration(days: 90)),
  year(Duration(days: 365));

  const ChatSearchPeriod(this.span);

  /// Null: no limit.
  final Duration? span;

  /// The oldest send time searched as of [now]; null for [all].
  DateTime? since(DateTime now) => switch (span) {
    final span? => now.subtract(span),
    null => null,
  };
}

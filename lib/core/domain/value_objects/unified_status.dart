/// The six unified board columns every provider's statuses normalize onto.
/// `order` is the left-to-right column order on the board.
enum UnifiedStatus {
  inbox(order: 0),
  todo(order: 1),
  inprogress(order: 2),
  review(order: 3),
  blocked(order: 4),
  done(order: 5);

  const UnifiedStatus({required this.order});

  final int order;

  static UnifiedStatus byId(String id) =>
      UnifiedStatus.values.firstWhere((s) => s.name == id);

  /// Columns in board order.
  static List<UnifiedStatus> get columns =>
      List.of(UnifiedStatus.values)..sort((a, b) => a.order.compareTo(b.order));
}

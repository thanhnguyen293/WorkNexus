/// Native ZenTao bug board columns.
///
/// These are intentionally separate from `UnifiedStatus`: ZenTao bugs have a
/// three-state lifecycle (`active`, `resolved`, `closed`) plus resolution codes.
enum ZenTaoBugColumn {
  newUnconfirmed(order: 0),
  confirmedToFix(order: 1),
  resolvedVerify(order: 2),
  postponed(order: 3),
  nonFix(order: 4),
  closed(order: 5);

  const ZenTaoBugColumn({required this.order});

  final int order;

  static List<ZenTaoBugColumn> get columns =>
      List.of(values)..sort((a, b) => a.order.compareTo(b.order));
}

const zentaoBugResolutionLabels = <String, String>{
  'fixed': 'Fixed',
  'bydesign': 'By design',
  'duplicate': 'Duplicate',
  'external': 'External',
  'notrepro': 'Irreproducible',
  'willnotfix': "Won't fix",
  'postponed': 'Postponed',
  'tostory': 'To story',
};

const zentaoNonFixResolutionLabels = <String, String>{
  'bydesign': 'By design',
  'duplicate': 'Duplicate',
  'external': 'External',
  'notrepro': 'Irreproducible',
  'willnotfix': "Won't fix",
  'tostory': 'To story',
};

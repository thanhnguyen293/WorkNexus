import '../../../../core/domain/value_objects/zentao_bug_column.dart';

/// A ZenTao server-side bug view (`bug-browse` browse type) that the bug board
/// pages on its own. Each board column draws on one of these and narrows it
/// further on the client where the view is wider than the column — so every
/// column can load more by itself without fetching the whole product first.
enum ZenTaoBugStream {
  /// Active and not yet confirmed: exactly the New/Unconfirmed column.
  unconfirmed('unconfirmed'),

  /// Every active bug; the board keeps the confirmed ones.
  unresolved('unresolved'),

  /// Resolved and waiting to be closed, whatever the resolution: split into
  /// Resolved/Verify, Postponed and Non-Fix by resolution.
  toClose('toclosed'),

  /// Every bug; ZenTao has no closed-only view, so Closed keeps the closed ones.
  all('all'),

  /// The bugs that concern the signed-in user, whatever their status: those
  /// assigned to, opened by and resolved by them — three ZenTao views, each
  /// read to its end, merged as one. On the Related-to-me tab this one view
  /// feeds every column.
  relatedToMe('assigntome', also: ['openedbyme', 'resolvedbyme']);

  const ZenTaoBugStream(this.code, {this.also = const []});

  /// The literal browse type ZenTao's bug-list API expects.
  final String code;

  /// Further browse types fetched alongside [code] and merged into this view.
  final List<String> also;

  /// Every browse type this view is made of.
  List<String> get codes => [code, ...also];

  /// The view [column] draws its bugs from — [relatedToMe] for every column
  /// on the Related-to-me tab ([related]).
  static ZenTaoBugStream of(ZenTaoBugColumn column, {bool related = false}) =>
      related
      ? relatedToMe
      : switch (column) {
          ZenTaoBugColumn.newUnconfirmed => unconfirmed,
          ZenTaoBugColumn.confirmedToFix => unresolved,
          ZenTaoBugColumn.resolvedVerify ||
          ZenTaoBugColumn.postponed ||
          ZenTaoBugColumn.nonFix => toClose,
          ZenTaoBugColumn.closed => all,
        };
}

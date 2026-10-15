/// The ZenTao "browse type" tabs for a product's bug board.
///
/// Each value is a server-side filtered view of a product's bugs (mirroring
/// ZenTao's own bug-board tabs), fetched fresh from the API on every tab switch
/// rather than derived locally. [code] is the exact literal ZenTao's bug-list
/// API expects — as the `?browseType=` query on `GET /products/{id}/bugs` and as
/// the `browseType` segment of the classic `bug-browse-…` action.
///
/// Declaration order is the display order in the tab strip; [unclosed] is the
/// default (matching ZenTao, which opens a bug board on "Unclosed").
enum ZenTaoBugBrowseType {
  all('all'),
  unclosed('unclosed'),
  reportedByMe('openedbyme'),
  assignedToMe('assigntome'),
  resolvedByMe('resolvedbyme'),
  assignedByMe('assignedbyme');

  const ZenTaoBugBrowseType(this.code);

  /// The literal value ZenTao's bug-list API expects for this view.
  final String code;
}

/// Built-in saved views (the sidebar "Views" section). Predicates are applied
/// in the filtering use case, keeping this enum pure.
enum SavedView {
  all,
  today,
  mine,
  review,
  blocked;

  static SavedView byId(String id) =>
      SavedView.values.firstWhere((v) => v.name == id);
}

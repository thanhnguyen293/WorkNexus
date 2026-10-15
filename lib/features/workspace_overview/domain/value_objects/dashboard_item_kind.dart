/// What a dashboard work item is. Bugs, tasks and stories are ZenTao tickets
/// that open in the detail panel; todos are personal and have no detail view.
enum DashboardItemKind {
  task,
  bug,
  story,
  todo;

  /// Whether the item can be loaded as a ticket (detail panel).
  bool get isTicket => this != todo;

  /// The kind behind a ZenTao `objectType` code, or null for other objects
  /// (projects, docs, …).
  static DashboardItemKind? fromObjectType(String? type) =>
      switch (type?.trim().toLowerCase()) {
        'task' => task,
        'bug' => bug,
        'story' => story,
        'todo' => todo,
        _ => null,
      };
}

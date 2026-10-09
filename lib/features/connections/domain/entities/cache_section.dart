/// A group of locally cached, server-synced data that can be cleared on its
/// own. Accounts, workspaces, settings, saved filters and chat sign-ins are
/// never part of the cache.
enum CacheSection {
  /// Tickets, their comments and activity, and the projects they belong to.
  tickets,

  /// The dashboard snapshot, ZenTao notifications and profiles.
  dashboard,

  /// Chat conversations, messages and contacts.
  chat,

  /// Saved translations of tickets and chat messages.
  translations,
}

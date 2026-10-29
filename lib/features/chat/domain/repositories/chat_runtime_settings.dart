/// The user's settings the chat backend applies as it works (downloads,
/// arriving messages), pushed in by the app whenever they change.
abstract interface class ChatRuntimeSettings {
  /// The most disk space attachments may use; older ones are dropped first.
  void setCacheLimit(int bytes);

  /// Largest video (bytes) downloaded on its own for its preview frame; 0
  /// downloads none until clicked.
  void setVideoAutoDownloadLimit(int bytes);

  /// Whether a reply that is just an emoji is a reaction as it arrives:
  /// then it never counts as unread. Off, it is a message like any other.
  void setReactions(bool on);
}

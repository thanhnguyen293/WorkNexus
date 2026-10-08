import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';
import '../entities/chat_user.dart';
import '../value_objects/chat_connection_status.dart';

/// ZenTao chat for a connected ZenTao account ([accountId] is the WorkNexus
/// account id). Local-first: everything received is written to the local DB
/// and the `watch*` streams read from it.
abstract class ChatRepository {
  Stream<ChatConnectionStatus> watchStatus(String accountId);

  /// Logs in with the account's saved ZenTao password. Safe to call again.
  Future<Result<void>> connect(String accountId);

  Future<void> disconnect(String accountId);

  /// Pins [fingerprint] for the account's chat server and reconnects.
  Future<Result<void>> trustCertificate(String accountId, String fingerprint);

  /// Conversations, most recently active first.
  Stream<List<ChatConversation>> watchConversations(String accountId);

  /// The newest [limit] messages of a chat, oldest first.
  Stream<List<ChatMessage>> watchMessages(
    String accountId,
    String chatGid, {
    int limit = 50,
  });

  Stream<List<ChatUser>> watchUsers(String accountId);

  /// Fetches the newest page of a chat from the server.
  Future<Result<void>> refreshMessages(String accountId, String chatGid);

  /// Fetches the page before the oldest stored message; returns how many
  /// messages arrived (0 = reached the beginning).
  Future<Result<int>> loadOlderMessages(String accountId, String chatGid);

  /// Shows the message immediately as pending, then sends it.
  Future<Result<void>> sendText(String accountId, String chatGid, String text);

  /// Re-sends a message that failed.
  Future<Result<void>> retrySend(String accountId, String messageGid);
}

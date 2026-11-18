import '../../../../core/error/result.dart';

/// Sends one text message on the user's behalf.
typedef LocalTextSend =
    Future<Result<void>> Function({
      required String accountId,
      required String chatGid,
      required String text,
      required bool markdown,
    });

/// One page further back in a chat's stored timeline: how many messages it
/// added, and whether the timeline now holds the chat's first message.
typedef ChatHistoryStep = ({int loaded, bool reachesStart});

/// Pages a chat's stored timeline one page further back.
typedef LocalHistoryLoad =
    Future<Result<ChatHistoryStep>> Function({
      required String accountId,
      required String chatGid,
      required int pageSize,
    });

/// A message's file or image, downloaded to a local file at [path].
typedef ChatAttachmentFile = ({
  String path,
  String name,
  int size,
  String? mimeType,
  bool isImage,
});

/// Downloads the file or image of server message [messageId].
typedef LocalAttachmentFetch =
    Future<Result<ChatAttachmentFile>> Function({
      required String accountId,
      required String chatGid,
      required int messageId,
    });

/// What the local API does for each request, through this app's chat session.
class ChatLocalApiHandlers {
  const ChatLocalApiHandlers({
    required this.send,
    required this.loadOlder,
    required this.attachment,
  });

  final LocalTextSend send;
  final LocalHistoryLoad loadOlder;
  final LocalAttachmentFetch attachment;
}

/// A local endpoint other programs on this computer — an AI assistant's MCP
/// server — use chat through: sending messages, loading older history and
/// downloading attachments with the chat session this app is already logged
/// into. Off unless the user turns it on in the chat settings.
abstract class ChatLocalApi {
  /// Starts answering requests with [handlers]. Calling it again while
  /// running only replaces [handlers].
  Future<Result<void>> start(ChatLocalApiHandlers handlers);

  /// Stops answering and forgets how it was reached.
  Future<Result<void>> stop();
}

import '../../../../core/error/result.dart';

/// Sends one text message on the user's behalf.
typedef LocalTextSend =
    Future<Result<void>> Function({
      required String accountId,
      required String chatGid,
      required String text,
      required bool markdown,
    });

/// A local endpoint other programs on this computer — an AI assistant's MCP
/// server — send chat messages through, using the chat session this app is
/// already logged into. Off unless the user turns it on in the chat settings.
abstract class ChatLocalApi {
  /// Starts answering requests, each sent with [send]. Calling it again while
  /// running only replaces [send].
  Future<Result<void>> start(LocalTextSend send);

  /// Stops answering and forgets how it was reached.
  Future<Result<void>> stop();
}

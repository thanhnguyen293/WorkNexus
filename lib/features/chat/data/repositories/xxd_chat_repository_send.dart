part of 'xxd_chat_repository.dart';

/// Sending, retracting and retrying messages through [ChatSender].
mixin _ChatSending on _XxdChatCore {
  // ---- send --------------------------------------------------------------------

  @override
  Future<Result<void>> sendText(
    String accountId,
    String chatGid,
    String text, {
    int? replyToId,
    bool markdown = false,
  }) => _sender.sendText(
    accountId,
    chatGid,
    text,
    replyToId: replyToId,
    markdown: markdown,
  );

  @override
  Future<Result<void>> sendEmoji(
    String accountId,
    String chatGid,
    String code,
  ) => _sender.sendEmoji(accountId, chatGid, code);

  @override
  Future<Result<void>> sendFile(
    String accountId,
    String chatGid, {
    required String name,
    required Uint8List bytes,
    String? mimeType,
    int? replyToId,
  }) => _sender.sendFile(
    accountId,
    chatGid,
    name: name,
    bytes: bytes,
    mimeType: mimeType,
    replyToId: replyToId,
  );

  @override
  Stream<double> watchUploadProgress(String messageGid) => _sender
      .uploadProgress
      .where((p) => p.gid == messageGid)
      .map((p) => p.sent);

  @override
  Future<Result<void>> retract(String accountId, String messageGid) =>
      _sender.retract(accountId, messageGid);

  @override
  Future<Result<void>> retrySend(String accountId, String messageGid) =>
      _sender.retrySend(accountId, messageGid);
}

part of 'xxd_chat_repository.dart';

/// Attachment downloads, video previews and the chat file cache.
mixin _ChatAttachments on _XxdChatCore {
  @override
  Future<Result<Uint8List>> loadAttachment(
    String accountId,
    MessageContent content, {
    bool thumbnail = false,
  }) => _attachments.load(
    accountId,
    _sessions[accountId],
    content,
    thumbnail: thumbnail,
  );

  @override
  Future<Result<String>> attachmentFile(
    String accountId,
    MessageContent content,
  ) => _attachments.localFile(accountId, _sessions[accountId], content);

  @override
  void cancelDownload(String accountId, MessageContent content) =>
      _attachments.cancel(accountId, content);

  /// Videos up to this size download on their own, to show a preview
  /// frame; bigger ones (all, at 0) show their size and download on tap.
  int _videoAutoDownloadBytes = 20 * 1024 * 1024;

  @override
  void setVideoAutoDownloadLimit(int bytes) => _videoAutoDownloadBytes = bytes;

  @override
  Future<Result<Duration>> videoDuration(
    String accountId,
    MessageContent video,
  ) async {
    if (!await _attachments.isCached(accountId, video)) {
      return const Err(NotFoundFailure('Video not downloaded'));
    }
    final path = await _attachments.cachedPath(accountId, video);
    final duration = path == null ? null : await _durations.durationOf(path);
    return duration == null
        ? const Err(NotFoundFailure('Unknown video length'))
        : Ok(duration);
  }

  @override
  Future<Result<Uint8List>> videoThumbnail(
    String accountId,
    MessageContent video,
  ) async {
    if (video case FileContent(:final size)
        when size > _videoAutoDownloadBytes) {
      // Downloaded on request since: a frame can be made from the file.
      if (!await _attachments.isCached(accountId, video)) {
        return const Err(NotFoundFailure('Video too large to preview'));
      }
    }
    // A frame made earlier outlives the video in the cache: no download.
    final cached = await _attachments.cachedPath(accountId, video);
    if (cached != null) {
      final frame = await _thumbnailer.cachedThumbnailOf(cached);
      if (frame != null) return Ok(frame);
    }
    final path = await attachmentFile(accountId, video);
    switch (path) {
      case Ok(:final value):
        final frame = await _thumbnailer.thumbnailOf(value);
        return frame == null
            ? const Err(NotFoundFailure('No preview frame'))
            : Ok(frame);
      case Err(:final failure):
        return Err(failure);
    }
  }

  @override
  Future<Result<ChatCacheUsage>> cacheUsage() => _cache.usage();

  @override
  Future<Result<void>> clearCache({String? accountId, String? chatGid}) =>
      _cache.clear(accountId: accountId, chatGid: chatGid);

  @override
  void setCacheLimit(int bytes) => _cache.setLimit(bytes);

  @override
  Stream<double> watchDownloadProgress(
    String accountId,
    MessageContent content,
  ) => _attachments.watchProgress(accountId, content);

  @override
  Future<bool> isAttachmentCached(String accountId, MessageContent content) =>
      _attachments.isCached(accountId, content);
}

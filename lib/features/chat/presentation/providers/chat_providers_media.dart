part of 'chat_providers.dart';

/// Attachment bytes (images), kept as a [Result] so a failed download renders
/// as a placeholder instead of an exception.
final chatAttachmentProvider = FutureProvider.autoDispose
    .family<
      Result<Uint8List>,
      ({String accountId, MessageContent content, bool thumbnail})
    >((ref, key) async {
      final result = await ref
          .watch(chatControllerProvider)
          .loadAttachment(key.accountId, key.content, thumbnail: key.thumbnail);
      // Loading an original downloads it: refresh "is it downloaded?" so
      // size badges go away.
      if (!key.thumbnail && result is Ok && ref.mounted) {
        ref.invalidate(
          chatAttachmentCachedProvider((
            accountId: key.accountId,
            content: key.content,
          )),
        );
      }
      return result;
    });

/// A chat's image and file messages stored locally, newest first.
final chatAttachmentsProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, ChatThreadKey>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .watchAttachments(key.accountId, key.chatGid),
    );

/// An attachment of a chat account (the key of the download providers).
typedef ChatAttachmentKey = ({String accountId, MessageContent content});

/// Whether an attachment's original is already downloaded.
final chatAttachmentCachedProvider = FutureProvider.autoDispose
    .family<bool, ChatAttachmentKey>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .isAttachmentCached(key.accountId, key.content),
    );

/// Download progress (0–1) of an attachment's original.
final chatDownloadProgressProvider = StreamProvider.autoDispose
    .family<double, ChatAttachmentKey>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .watchDownloadProgress(key.accountId, key.content),
    );

/// Attachments being downloaded because the user tapped them.
final chatDownloadingProvider = StateProvider<Set<ChatAttachmentKey>>(
  (ref) => const {},
);

/// Disk space used by chat attachments (re-read when the dialog opens).
final chatCacheUsageProvider =
    FutureProvider.autoDispose<Result<ChatCacheUsage>>(
      (ref) => ref.watch(chatRepositoryProvider).cacheUsage(),
    );

/// Upload progress (0–1) of a pending file message, by message gid.
final chatUploadProgressProvider = StreamProvider.autoDispose
    .family<double, String>(
      (ref, gid) => ref.watch(chatRepositoryProvider).watchUploadProgress(gid),
    );

/// Preview frame of a video message.
final chatVideoThumbnailProvider = FutureProvider.autoDispose
    .family<Result<Uint8List>, ({String accountId, MessageContent video})>((
      ref,
      key,
    ) {
      // Re-made once a video too big to preview is downloaded on request.
      ref.watch(
        chatAttachmentCachedProvider((
          accountId: key.accountId,
          content: key.video,
        )),
      );
      return ref
          .watch(chatControllerProvider)
          .videoThumbnail(key.accountId, key.video);
    });

/// Length of a downloaded video. Waits for the preview frame, whose making
/// downloads small videos, and re-reads once a big one is downloaded on
/// request.
final chatVideoDurationProvider = FutureProvider.autoDispose
    .family<Result<Duration>, ({String accountId, MessageContent video})>((
      ref,
      key,
    ) async {
      await ref.watch(chatVideoThumbnailProvider(key).future);
      return ref
          .watch(chatRepositoryProvider)
          .videoDuration(key.accountId, key.video);
    });

/// Preview card data for a web link in a message (null = nothing to show).
final chatLinkPreviewProvider = FutureProvider.autoDispose
    .family<LinkPreview?, String>((ref, url) async {
      final result = await LoadLinkPreview(getIt<LinkPreviewRepository>())(url);
      // Keep previews while the app runs: the repository caches them anyway,
      // and re-creating the provider on every scroll would flicker.
      ref.keepAlive();
      return result.valueOrNull;
    });

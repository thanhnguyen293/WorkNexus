import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';
import 'chat_video_dialog.dart';

/// Opens an attachment: right away when it is downloaded; otherwise it is
/// downloaded first and opened only if its message is still on screen when
/// the download ends (the user may have scrolled on or opened something
/// else meanwhile).
Future<void> openAttachment(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required MessageContent content,
  required Future<void> Function() open,
}) async {
  final key = (accountId: accountId, content: content);
  // The widget may be gone by the time the download ends; the container
  // outlives it.
  final container = ProviderScope.containerOf(context, listen: false);
  if (await container.read(chatAttachmentCachedProvider(key).future)) {
    if (context.mounted) await open();
    return;
  }
  final downloading = container.read(chatDownloadingProvider.notifier);
  if (downloading.state.contains(key)) return;
  downloading.state = {...downloading.state, key};
  final result = await container
      .read(chatControllerProvider)
      .attachmentFile(accountId, content);
  downloading.state = {...downloading.state}..remove(key);
  container.invalidate(chatAttachmentCachedProvider(key));
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      if (isOnScreen(context)) await open();
    // Stopped by the user: nothing to report.
    case Err(failure: CancelledFailure()):
      break;
    case Err(:final failure):
      showChatFailure(context, failure);
  }
}

/// Shows an attachment in the system file manager: the copy the user last
/// saved ("Save as…") while it exists, else the app's own file — downloaded
/// first (with progress, like [openAttachment]) when it is not here yet.
Future<void> revealAttachment(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required MessageContent content,
}) async {
  final saved = await ref
      .read(chatControllerProvider)
      .savedAttachmentCopy(accountId, content);
  if (saved != null) return revealInFileManager(saved);
  if (!context.mounted) return;
  await _withLocalFile(
    context,
    ref,
    accountId: accountId,
    content: content,
    use: revealInFileManager,
  );
}

/// Asks where to save an attachment and copies it there, downloading it
/// first when it is not here yet; says "Saved" when done.
Future<void> saveAttachment(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required MessageContent content,
  required String name,
}) => _withLocalFile(
  context,
  ref,
  accountId: accountId,
  content: content,
  use: (_) => saveAttachmentCopyAs(
    context,
    ref,
    accountId: accountId,
    content: content,
    name: name,
  ),
);

/// Asks where to save an attachment already on this device and copies it
/// there (remembered for [revealAttachment]); says "Saved" when done.
Future<void> saveAttachmentCopyAs(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required MessageContent content,
  required String name,
}) async {
  final saved = AppL10n.of(context).chatSaved;
  final target = await pickSaveLocation(name);
  if (target == null) return;
  final result = await ref
      .read(chatControllerProvider)
      .saveAttachmentCopy(accountId, content, target);
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      showChatSnack(context, saved);
    case Err(:final failure):
      showChatFailure(context, failure);
  }
}

/// Runs [use] on the attachment's local file once it is on this device.
Future<void> _withLocalFile(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required MessageContent content,
  required Future<void> Function(String path) use,
}) => openAttachment(
  context,
  ref,
  accountId: accountId,
  content: content,
  open: () async {
    final file = await ref
        .read(chatControllerProvider)
        .attachmentFile(accountId, content);
    switch (file) {
      case Ok(:final value):
        await use(value);
      case Err(:final failure):
        if (context.mounted) showChatFailure(context, failure);
    }
  },
);

/// Stops downloading an attachment opened with [openAttachment].
void cancelAttachmentDownload(
  WidgetRef ref, {
  required String accountId,
  required MessageContent content,
}) => ref.read(chatControllerProvider).cancelDownload(accountId, content);

/// Whether [context]'s widget is visible: on the top route and overlapping
/// its scroll view's viewport.
bool isOnScreen(BuildContext context) {
  if (ModalRoute.of(context)?.isCurrent == false) return false;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return false;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
  if (viewport is! RenderBox || !viewport.hasSize) return true;
  return (viewport.localToGlobal(Offset.zero) & viewport.size).overlaps(rect);
}

/// Opens a file message (downloading it first when needed): a video plays
/// in-app, anything else opens with the system's default app.
Future<void> openChatFile(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required FileContent file,
  String? chatGid,
}) => openAttachment(
  context,
  ref,
  accountId: accountId,
  content: file,
  open: () async {
    if (isVideoFile(file)) {
      await ChatVideoDialog.show(
        context,
        accountId: accountId,
        video: file,
        chatGid: chatGid,
      );
      return;
    }
    final path = await ref
        .read(chatControllerProvider)
        .attachmentFile(accountId, file);
    if (!context.mounted) return;
    switch (path) {
      case Ok(:final value):
        await openExternally(value);
      case Err(:final failure):
        showChatFailure(context, failure);
    }
  },
);

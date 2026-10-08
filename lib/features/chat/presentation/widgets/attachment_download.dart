import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';

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
    case Err(:final failure):
      showChatFailure(context, failure);
  }
}

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

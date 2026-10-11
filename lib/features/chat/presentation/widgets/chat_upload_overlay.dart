import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';

/// Stops sending own file message [messageGid] while it uploads; the
/// message goes away. A failure is shown.
Future<void> cancelChatUpload(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required String messageGid,
}) async {
  final result = await ref
      .read(chatControllerProvider)
      .cancelUpload(accountId, messageGid);
  if (result case Err(:final failure)) {
    if (context.mounted) showChatFailure(context, failure);
  }
}

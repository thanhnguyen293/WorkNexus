import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_bubble_theme.dart';
import 'chat_snack.dart';

/// The time under the last message of a run — or, while it is not sent, its
/// state (tap a failed message to retry).
class MessageFooter extends ConsumerWidget {
  const MessageFooter({
    super.key,
    required this.accountId,
    required this.message,
    this.tick,
  });

  final String accountId;
  final ChatMessage message;

  /// Colour of a "sent" tick after the time (Telegram style), or none.
  final Color? tick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final style = context.typography.captionSm.copyWith(
      color: ChatBubbleTheme.of(context).meta,
    );
    final uploading = switch (message.content) {
      FileContent(fileId: 0) => true,
      _ => false,
    };
    final child = switch (message.sendState) {
      SendState.sent => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(DateFormat('HH:mm').format(message.sentAt), style: style),
          if (tick case final color?) ...[
            SizedBox(width: context.spacing.xxs),
            Icon(
              PhosphorIconsLight.check,
              size: context.spacing.xl,
              color: color,
            ),
          ],
        ],
      ),
      SendState.pending => Text(
        uploading ? l.chatUploading : l.chatSending,
        style: style,
      ),
      SendState.failed => InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () async {
          final result = await ref
              .read(chatControllerProvider)
              .retry(accountId, message.gid);
          if (result case Err(:final failure)) {
            if (context.mounted) showChatFailure(context, failure);
          }
        },
        child: Text(
          l.chatSendFailed,
          style: style.copyWith(color: c.error, fontWeight: FontWeight.w600),
        ),
      ),
    };
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xs),
      child: child,
    );
  }
}

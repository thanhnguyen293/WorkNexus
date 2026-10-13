import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_bubble_theme.dart';
import 'chat_snack.dart';

/// A message's time — or, while it is not sent, its state (tap a failed
/// message to retry). The caller places it (under the content, or at the
/// bubble's bottom-end corner).
class MessageFooter extends ConsumerWidget {
  const MessageFooter({
    super.key,
    required this.accountId,
    required this.message,
    this.tick,
    this.replies,
    this.onOpenReplies,
  });

  final String accountId;
  final ChatMessage message;

  /// Colour of a "sent" tick after the time (Telegram style), or none.
  final Color? tick;

  /// Reply count of a thread root, shown before the time (Telegram style);
  /// tapping it calls [onOpenReplies].
  final int? replies;
  final VoidCallback? onOpenReplies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final ink = ChatBubbleTheme.of(context);
    final style = context.typography.captionSm.copyWith(
      color: ink.meta,
      fontSize: ink.metaSize,
    );
    final iconSize = (ink.metaSize ?? style.fontSize ?? 11) * 1.1;
    final uploading = switch (message.content) {
      FileContent(fileId: 0) => true,
      _ => false,
    };
    final child = switch (message.sendState) {
      SendState.sent => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replies case final count?) ...[
            _RepliesCount(
              count: count,
              style: style,
              iconSize: iconSize,
              onTap: onOpenReplies,
            ),
            SizedBox(width: context.spacing.md),
          ],
          Text(DateFormat('HH:mm').format(message.sentAt), style: style),
          if (tick case final color?) ...[
            SizedBox(width: context.spacing.xxs),
            Icon(LucideIcons.check300, size: iconSize, color: color),
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
          style: style.copyWith(color: c.error, fontWeight: FontWeight.w500),
        ),
      ),
    };
    return child;
  }
}

/// "↩ 3": how many replies a thread root has; opens the thread.
class _RepliesCount extends StatelessWidget {
  const _RepliesCount({
    required this.count,
    required this.style,
    required this.iconSize,
    required this.onTap,
  });

  final int count;
  final TextStyle style;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppL10n.of(context).chatReplies(count),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.reply300, size: iconSize, color: style.color),
            SizedBox(width: context.spacing.xxs),
            Text('$count', style: style),
          ],
        ),
      ),
    );
  }
}

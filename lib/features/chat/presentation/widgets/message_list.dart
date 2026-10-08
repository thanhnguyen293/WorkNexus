import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';
import 'chat_style.dart';
import 'message_bubble.dart';

/// The messages of one chat, newest at the bottom, with "load earlier" on top.
/// New messages arriving while it is open are marked read.
class MessageList extends ConsumerStatefulWidget {
  const MessageList({
    super.key,
    required this.thread,
    required this.showSenders,
  });

  final ChatThreadKey thread;
  final bool showSenders;

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  bool _loadingOlder = false;
  bool _reachedStart = false;

  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    final t = widget.thread;
    final result = await ref
        .read(chatControllerProvider)
        .loadOlder(t.accountId, t.chatGid);
    if (!mounted) return;
    setState(() => _loadingOlder = false);
    switch (result) {
      case Ok(:final value) when value > 0:
        ref.read(chatMessageLimitProvider(t).notifier).state += value;
      case Ok():
        setState(() => _reachedStart = true);
      case Err(:final failure):
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    ref.listen(chatMessagesProvider(t), (previous, next) {
      final before = previous?.asData?.value.length ?? 0;
      final after = next.asData?.value.length ?? 0;
      if (after > before) {
        ref.read(chatControllerProvider).markRead(t.accountId, t.chatGid);
      }
    });
    final messagesAsync = ref.watch(chatMessagesProvider(t));
    final users =
        ref.watch(chatUsersProvider(t.accountId)).asData?.value ??
        const <int, ChatUser>{};
    final messages = messagesAsync.asData?.value ?? const <ChatMessage>[];
    if (messagesAsync.isLoading && messages.isEmpty) {
      return const AppInlineSpinner();
    }
    final summaries = ref.watch(chatThreadSummariesProvider(t));
    // Newest first (reversed list); a day divider follows the oldest message
    // of each day, i.e. sits above it on screen. The header is the last item.
    final style = ChatStyle.of(
      ref.watch(appSettingsProvider.select((s) => s.chatAppearance)),
      context,
    );
    // Styles without per-message times get a centered time separator after
    // a pause (Messenger ~15 min, WeChat ~5 min).
    final markerGap = style.separatorGap;
    final items = <Object>[];
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      items.add(message);
      final previous = index > 0 ? messages[index - 1] : null;
      if (previous == null ||
          !DateUtils.isSameDay(previous.sentAt, message.sentAt)) {
        items.add(DateUtils.dateOnly(message.sentAt));
      } else if (markerGap != null &&
          message.sentAt.difference(previous.sentAt) >= markerGap) {
        items.add(_TimeMarker(message.sentAt));
      }
    }
    return ColoredBox(
      color: style.palette.background,
      child: ListView.builder(
        reverse: true,
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.xl5,
          vertical: context.spacing.xl3,
        ),
        itemCount: items.length + 1,
        itemBuilder: (context, i) {
          if (i == items.length) {
            return _ListHeader(
              reachedStart: _reachedStart,
              loading: _loadingOlder,
              onLoadOlder: _loadOlder,
            );
          }
          final item = items[i];
          if (item is DateTime) {
            return _Separator(style: style, label: chatDayLabel(context, item));
          }
          if (item is _TimeMarker) {
            return _Separator(
              style: style,
              label: DateFormat('HH:mm').format(item.at),
            );
          }
          final message = item as ChatMessage;
          final older = i + 1 < items.length ? items[i + 1] : null;
          final newer = i > 0 ? items[i - 1] : null;
          return MessageBubble(
            key: ValueKey(message.gid),
            chat: t,
            message: message,
            users: users,
            firstOfRun: !_sameRun(older, message),
            lastOfRun: !_sameRun(newer, message),
            showSender: widget.showSenders,
            thread: summaries[message.serverId],
            onOpenThread: (id) => openReplyThread(ref, t, id),
          );
        },
      ),
    );
  }
}

/// A centered time marker in the list.
final class _TimeMarker {
  const _TimeMarker(this.at);
  final DateTime at;
}

/// Consecutive messages from one sender within a few minutes form a run:
/// one name, one avatar, one timestamp, tighter spacing.
bool _sameRun(Object? other, ChatMessage message) =>
    other is ChatMessage &&
    other.senderId == message.senderId &&
    other.sentAt.difference(message.sentAt).abs() <= const Duration(minutes: 5);

/// A centered date or time separator in the chat style's look: a pill
/// (Telegram, Zalo), plain text (Messenger, WeChat) or text between hairlines.
class _Separator extends StatelessWidget {
  const _Separator({required this.style, required this.label});

  final ChatStyle style;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = style.palette;
    final text = Text(
      label,
      style: context.typography.captionStrong.copyWith(color: p.separatorText),
    );
    final Widget child = switch (style.separator) {
      ChatSeparatorStyle.pill => DecoratedBox(
        decoration: BoxDecoration(
          color: p.separatorFill,
          borderRadius: BorderRadius.circular(context.radii.pill),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.xl,
            vertical: context.spacing.xs,
          ),
          child: text,
        ),
      ),
      ChatSeparatorStyle.plain => text,
      ChatSeparatorStyle.hairline => Row(
        children: [
          Expanded(child: Divider(color: context.colors.border, height: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
            child: text,
          ),
          Expanded(child: Divider(color: context.colors.border, height: 1)),
        ],
      ),
    };
    return Padding(
      padding: EdgeInsets.only(
        top: context.spacing.xl4,
        bottom: context.spacing.xs,
      ),
      child: Center(child: child),
    );
  }
}

/// Top of the thread: "load earlier messages", or the start marker.
class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.reachedStart,
    required this.loading,
    required this.onLoadOlder,
  });

  final bool reachedStart;
  final bool loading;
  final VoidCallback onLoadOlder;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xl),
      child: Center(
        child: reachedStart
            ? Text(
                l.chatBeginning,
                style: context.typography.caption.copyWith(
                  color: context.colors.textTertiary,
                ),
              )
            : AppButton.textNeutral(
                size: AppButtonSize.small,
                isLoading: loading,
                onPressed: loading ? null : onLoadOlder,
                child: Text(l.chatLoadOlder),
              ),
      ),
    );
  }
}

/// Opens the reply thread that [messageId] belongs to beside chat [chat].
void openReplyThread(WidgetRef ref, ChatThreadKey chat, int messageId) {
  final replies = ref.read(chatRepliesProvider(chat)).asData?.value ?? const [];
  ref.read(openReplyThreadProvider(chat).notifier).state = ref
      .read(chatControllerProvider)
      .threadRootOf(messageId, replies);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/open_account_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_trust_preview.dart';
import '../widgets/chat_layout.dart';
import '../widgets/chat_notification_banner.dart';
import '../widgets/chat_status_banner.dart';
import '../widgets/chat_trust_dialog.dart';
import '../widgets/chat_trust_gate.dart';
import '../widgets/conversation_list_pane.dart';
import '../widgets/thread_pane.dart';

/// The ZenTao chat view: connection banner, chat list and the open thread.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.onViewProfile});

  final OpenAccountProfile? onViewProfile;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  /// Moves the messages' background from one chat's pane to the next, so
  /// switching chats keeps it on screen instead of building and painting it
  /// again (each pane is keyed per chat).
  final _background = GlobalKey(debugLabel: 'chat-background');

  /// The certificate already put to the user on this visit: opening chat
  /// asks once (chat cannot work until it is confirmed), and again only for
  /// a different certificate.
  String? _askedFingerprint;

  void _askToTrust(String accountId, ChatNeedsTrust request) {
    if (_askedFingerprint == request.fingerprint) return;
    _askedFingerprint = request.fingerprint;
    // Not during build: a dialog is a route push.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ChatTrustDialog.show(context, accountId: accountId, request: request);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final accountId = ref.watch(selectedChatAccountIdProvider);
    if (accountId == null) {
      return Center(child: AppInlineNote(text: l.chatNoZentaoAccount));
    }
    // A debug preview stands in for the server asking (see
    // ChatTrustDebugButton).
    final status =
        ref.watch(chatTrustPreviewProvider) ??
        ref.watch(chatStatusProvider(accountId)).asData?.value;
    if (status is ChatNeedsTrust) {
      _askToTrust(accountId, status);
    } else {
      // Settled: a later request for the same certificate asks again.
      _askedFingerprint = null;
    }
    final chatGid = ref.watch(selectedChatGidProvider(accountId));
    final thread = chatGid == null
        ? null
        : (accountId: accountId, chatGid: chatGid);
    return ColoredBox(
      color: context.colors.background,
      child: Column(
        children: [
          ChatStatusBanner(accountId: accountId),
          const ChatNotificationBanner(),
          Expanded(
            child: status is ChatNeedsTrust
                ? ChatTrustGate(accountId: accountId, request: status)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final layout = ChatLayout.of(constraints.maxWidth);
                      return ChatLayoutScope(
                        layout: layout,
                        child: Row(
                          children: [
                            SizedBox(
                              width: layout.compactList
                                  ? kChatListCompactWidth
                                  : kChatListWidth,
                              child: ConversationListPane(
                                accountId: accountId,
                                compact: layout.compactList,
                                onViewProfile: widget.onViewProfile,
                              ),
                            ),
                            Expanded(
                              child: chatGid == null
                                  ? Center(
                                      child: AppInlineNote(
                                        text: l.chatSelectConversation,
                                      ),
                                    )
                                  : ThreadPane(
                                      key: ValueKey('$accountId/$chatGid'),
                                      thread: thread!,
                                      backgroundKey: _background,
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

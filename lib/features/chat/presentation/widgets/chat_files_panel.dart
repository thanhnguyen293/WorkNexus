import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_layout.dart';
import 'chat_panel_tab_bar.dart';
import 'chat_panels.dart';
import 'chat_shared_files.dart';
import 'chat_side_panel_frame.dart';

/// Beside the chat: every photo/video (grid) and file (list) shared in it,
/// newest first, from the messages loaded on this computer.
class ChatFilesPanel extends ConsumerWidget {
  const ChatFilesPanel({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final infoRoom = ChatLayoutScope.of(context).infoRoom;
    final attachments = ref.watch(chatAttachmentsProvider(thread));
    final all = attachments.value;
    final Widget body;
    if (all == null) {
      body = attachments.hasError
          ? AppStateView.error(
              compact: true,
              onRetry: () => ref.invalidate(chatAttachmentsProvider(thread)),
            )
          : const AppStateView.loading(compact: true);
    } else {
      final (:media, :files) = splitChatAttachments(all);
      body = DefaultTabController(
        length: 2,
        child: Column(
          children: [
            ChatPanelTabBar(
              labels: [
                '${l.chatMedia} (${media.length})',
                '${l.chatFiles} (${files.length})',
              ],
              height: kChatSubHeaderHeight,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _FilesTab(
                    isEmpty: media.isEmpty,
                    emptyIcon: LucideIcons.image300,
                    emptyTitle: l.chatNoMedia,
                    children: [
                      ChatMediaGrid(
                        accountId: thread.accountId,
                        media: media,
                        columns: 3,
                      ),
                    ],
                  ),
                  _FilesTab(
                    isEmpty: files.isEmpty,
                    emptyIcon: LucideIcons.file300,
                    emptyTitle: l.chatNoFiles,
                    children: [
                      for (final m in files)
                        ChatFileRow(message: m, file: m.content as FileContent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return ChatSidePanelFrame(
      title: l.chatFilesAndMedia,
      onBack: () => backToChatInfo(ref, thread, infoRoom: infoRoom),
      onClose: infoRoom ? null : () => closeChatSidePanel(ref, thread),
      // On the header's colour, not the window's, so it reads as a panel.
      child: ColoredBox(color: context.colors.surface, child: body),
    );
  }
}

/// One tab of the panel: its items above the "only what's loaded here" hint,
/// or an empty state carrying that hint.
class _FilesTab extends StatelessWidget {
  const _FilesTab({
    required this.isEmpty,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.children,
  });

  final bool isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    if (isEmpty) {
      return AppStateView.empty(
        compact: true,
        icon: emptyIcon,
        title: emptyTitle,
        message: l.chatFilesLoadedHint,
      );
    }
    return ListView(
      padding: EdgeInsets.all(s.xl),
      children: [
        ...children,
        Padding(
          padding: EdgeInsets.only(top: s.xl),
          child: Text(
            l.chatFilesLoadedHint,
            style: context.typography.caption.copyWith(
              color: context.colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

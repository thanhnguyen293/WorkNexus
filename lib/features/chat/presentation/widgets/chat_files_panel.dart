import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
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
    final c = context.colors;
    final s = context.spacing;
    final all = ref.watch(chatAttachmentsProvider(thread)).value ?? const [];
    final (:media, :files) = splitChatAttachments(all);
    final hint = Padding(
      padding: EdgeInsets.only(top: s.xl),
      child: Text(
        l.chatFilesLoadedHint,
        style: context.typography.caption.copyWith(color: c.textTertiary),
      ),
    );
    return ChatSidePanelFrame(
      title: l.chatFilesAndMedia,
      onClose: () => closeChatSidePanel(ref, thread),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: c.accent,
              unselectedLabelColor: c.textSecondary,
              indicatorColor: c.accent,
              tabs: [
                Tab(text: '${l.chatMedia} (${media.length})'),
                Tab(text: '${l.chatFiles} (${files.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: EdgeInsets.all(s.xl),
                    children: [
                      if (media.isEmpty)
                        AppInlineNote(text: l.chatNoMedia)
                      else
                        ChatMediaGrid(
                          accountId: thread.accountId,
                          media: media,
                          columns: 3,
                        ),
                      hint,
                    ],
                  ),
                  ListView(
                    padding: EdgeInsets.all(s.xl),
                    children: [
                      if (files.isEmpty) AppInlineNote(text: l.chatNoFiles),
                      for (final m in files)
                        ChatFileRow(message: m, file: m.content as FileContent),
                      hint,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

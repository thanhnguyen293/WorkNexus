import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_layout.dart';
import 'chat_panels.dart';
import 'chat_shared_files.dart';
import 'chat_side_panel_frame.dart';

/// Number of thumbnails and file rows previewed in the info panel.
const _kPreviewMedia = 8;
const _kPreviewFiles = 3;

/// The info panel's "Photos & videos" and "Files" cards: a preview of the
/// newest ones and "See all", which opens the files panel.
class ChatInfoFilesSection extends ConsumerWidget {
  const ChatInfoFilesSection({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final all = ref.watch(chatAttachmentsProvider(thread)).value ?? const [];
    final (:media, :files) = splitChatAttachments(all);
    final infoRoom = ChatLayoutScope.of(context).infoRoom;
    void seeAll() => toggleChatSidePanel(
      ref,
      thread,
      ChatSidePanel.files,
      infoRoom: infoRoom,
    );
    return Column(
      children: [
        ChatPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: '${l.chatMedia} (${media.length})',
                onSeeAll: media.isEmpty ? null : seeAll,
              ),
              SizedBox(height: s.md),
              if (media.isEmpty)
                AppInlineNote(text: l.chatNoMedia)
              else
                ChatMediaGrid(
                  accountId: thread.accountId,
                  media: media.take(_kPreviewMedia).toList(),
                ),
            ],
          ),
        ),
        ChatPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: '${l.chatFiles} (${files.length})',
                onSeeAll: files.isEmpty ? null : seeAll,
              ),
              SizedBox(height: s.sm),
              if (files.isEmpty)
                AppInlineNote(text: l.chatNoFiles)
              else
                for (final m in files.take(_kPreviewFiles))
                  ChatFileRow(message: m, file: m.content as FileContent),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card title with an optional "See all" link.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(AppL10n.of(context).chatSeeAll),
          ),
      ],
    );
  }
}

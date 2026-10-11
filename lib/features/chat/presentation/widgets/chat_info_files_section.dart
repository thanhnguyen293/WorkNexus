import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
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
    final attachments = ref.watch(chatAttachmentsProvider(thread));
    final all = attachments.value;
    final infoRoom = ChatLayoutScope.of(context).infoRoom;
    void seeAll() => toggleChatSidePanel(
      ref,
      thread,
      ChatSidePanel.files,
      infoRoom: infoRoom,
    );
    if (all == null) {
      // Not "No files": the list isn't known yet, or failed to load.
      final Widget pending = attachments.hasError
          ? AppInlineNote(text: l.stateLoadFailedTitle, isError: true)
          : const AppInlineSpinner();
      return Column(
        children: [
          _Card(title: l.chatMedia, onSeeAll: null, child: pending),
          _Card(title: l.chatFiles, onSeeAll: null, child: pending),
        ],
      );
    }
    final (:media, :files) = splitChatAttachments(all);
    return Column(
      children: [
        _Card(
          title: '${l.chatMedia} (${media.length})',
          onSeeAll: media.isEmpty ? null : seeAll,
          child: media.isEmpty
              ? AppInlineNote(text: l.chatNoMedia)
              : ChatMediaGrid(
                  accountId: thread.accountId,
                  media: media.take(_kPreviewMedia).toList(),
                ),
        ),
        _Card(
          title: '${l.chatFiles} (${files.length})',
          onSeeAll: files.isEmpty ? null : seeAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

/// One card: a title with an optional "See all" link above [child].
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.onSeeAll,
    required this.child,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ChatPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (onSeeAll case final seeAll?)
                AppButton.textNeutral(
                  size: AppButtonSize.extraSmall,
                  onPressed: seeAll,
                  child: Text(AppL10n.of(context).chatSeeAll),
                ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          child,
        ],
      ),
    );
  }
}

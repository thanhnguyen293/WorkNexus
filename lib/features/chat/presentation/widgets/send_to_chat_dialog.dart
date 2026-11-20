import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/send_link_providers.dart';
import 'chat_snack.dart';
import 'chat_target_picker.dart';

/// Sends a link (a ticket from its detail panel) into one or more chats of
/// [accountId], with an optional message above it. Lists only chats the
/// user may post in.
class SendToChatDialog extends ConsumerStatefulWidget {
  const SendToChatDialog({
    super.key,
    required this.accountId,
    required this.title,
    required this.link,
  });

  final String accountId;

  /// What is being sent, as the dialog shows it (the link goes in the message).
  final String title;
  final String link;

  static Future<void> show(
    BuildContext context, {
    required String accountId,
    required String title,
    required String link,
  }) => showDialog<void>(
    context: context,
    builder: (_) =>
        SendToChatDialog(accountId: accountId, title: title, link: link),
  );

  @override
  ConsumerState<SendToChatDialog> createState() => _SendToChatDialogState();
}

class _SendToChatDialogState extends ConsumerState<SendToChatDialog> {
  final _note = TextEditingController();
  final _selected = <String>[];
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _toggle(String chatGid) => setState(
    () => _selected.contains(chatGid)
        ? _selected.remove(chatGid)
        : _selected.add(chatGid),
  );

  Future<void> _send() async {
    setState(() => _busy = true);
    final count = _selected.length;
    final result = await ref
        .read(sendLinkToChatsProvider)
        .call(
          accountId: widget.accountId,
          link: widget.link,
          note: _note.text,
          toChatGids: List.of(_selected),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        showChatSnack(context, AppL10n.of(context).sentToChat(count));
      case Err(:final failure):
        setState(() => _busy = false);
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final l = AppL10n.of(context);
    // A fixed height: searching must not make the dialog grow and shrink.
    final height = (MediaQuery.sizeOf(context).height * 0.8).clamp(
      360.0,
      640.0,
    );
    final canSend = _selected.isNotEmpty && !_busy;
    return AppDialogFrame(
      title: l.sendToChat,
      leadingIcon: LucideIcons.send300,
      maxWidth: context.sizes.dialogSm,
      maxHeight: height,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.chatCancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          isLoading: _busy,
          isDisabled: _selected.isEmpty,
          onPressed: canSend ? _send : null,
          child: Text(l.sendToChatTo(_selected.length)),
        ),
      ],
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.bodySm.copyWith(color: c.textSecondary),
              ),
              SizedBox(height: s.xl),
              TextField(
                key: const ValueKey<String>('send-to-chat-note'),
                controller: _note,
                minLines: 2,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                style: t.body.copyWith(color: c.textPrimary),
                decoration: appInputDecoration(
                  context,
                  hint: l.sendToChatNoteHint,
                ),
              ),
              SizedBox(height: s.xl),
              Expanded(
                child: ChatTargetPicker(
                  accountId: widget.accountId,
                  selected: _selected,
                  onToggle: _toggle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

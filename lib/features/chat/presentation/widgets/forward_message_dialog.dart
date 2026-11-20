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
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';
import 'chat_target_picker.dart';

/// Picks one or more chats of the message's account and forwards the
/// message to them. Lists only chats the user may post in.
class ForwardMessageDialog extends ConsumerStatefulWidget {
  const ForwardMessageDialog({super.key, required this.message});

  final ChatMessage message;

  static Future<void> show(BuildContext context, ChatMessage message) =>
      showDialog<void>(
        context: context,
        builder: (_) => ForwardMessageDialog(message: message),
      );

  @override
  ConsumerState<ForwardMessageDialog> createState() =>
      _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends ConsumerState<ForwardMessageDialog> {
  final _selected = <String>[];
  bool _busy = false;

  void _toggle(String chatGid) => setState(
    () => _selected.contains(chatGid)
        ? _selected.remove(chatGid)
        : _selected.add(chatGid),
  );

  Future<void> _forward() async {
    setState(() => _busy = true);
    final count = _selected.length;
    final result = await ref
        .read(chatControllerProvider)
        .forward(widget.message, toChatGids: List.of(_selected));
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        showChatSnack(context, AppL10n.of(context).chatForwarded(count));
      case Err(:final failure):
        setState(() => _busy = false);
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    // A fixed height: searching must not make the dialog grow and shrink.
    final height = (MediaQuery.sizeOf(context).height * 0.8).clamp(
      320.0,
      600.0,
    );
    return AppDialogFrame(
      title: l.chatForwardTitle,
      leadingIcon: LucideIcons.forward300,
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
          onPressed: _selected.isEmpty || _busy ? null : _forward,
          child: Text(
            _selected.length > 1
                ? l.chatForwardTo(_selected.length)
                : l.chatForward,
          ),
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
                chatPreview(context, widget.message),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: s.xl),
              Expanded(
                child: ChatTargetPicker(
                  accountId: widget.message.accountId,
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

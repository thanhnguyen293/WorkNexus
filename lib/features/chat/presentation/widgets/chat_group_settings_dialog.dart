import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../core/widgets/quick_settings_segmented.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/value_objects/chat_committers.dart';
import '../providers/chat_group_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_committer_picker.dart';
import 'chat_snack.dart';

/// A group's settings, for its owner and admins: public or not, whether only
/// they add people, and who may post. Saved together, as the official client
/// does.
class ChatGroupSettingsDialog extends ConsumerStatefulWidget {
  const ChatGroupSettingsDialog({
    super.key,
    required this.thread,
    required this.chat,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;

  static Future<void> show(
    BuildContext context, {
    required ChatThreadKey thread,
    required ChatConversation chat,
  }) => showDialog<void>(
    context: context,
    builder: (_) => ChatGroupSettingsDialog(thread: thread, chat: chat),
  );

  @override
  ConsumerState<ChatGroupSettingsDialog> createState() =>
      _ChatGroupSettingsDialogState();
}

class _ChatGroupSettingsDialogState
    extends ConsumerState<ChatGroupSettingsDialog> {
  late bool _public = widget.chat.isPublic;
  late bool _adminInvite = widget.chat.adminInvite;
  late final _initial = ChatCommitters.parse(widget.chat.committers);
  late ChatSendScope _scope = _initial.scope;
  late final Set<int> _picked = {..._initial.userIds};
  bool _saving = false;

  bool get _canSave =>
      !_saving && (_scope != ChatSendScope.selected || _picked.isNotEmpty);

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final result = await ref
        .read(chatGroupControllerProvider)
        .updateSettings(
          widget.chat,
          isPublic: _public,
          adminInvite: _adminInvite,
          committers: ChatCommitters(_scope, _picked),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        setState(() => _saving = false);
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final height = (MediaQuery.sizeOf(context).height * 0.85).clamp(
      320.0,
      640.0,
    );
    return AppDialogFrame(
      title: l.chatGroupSettings,
      maxWidth: context.sizes.dialogMd,
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
          isLoading: _saving,
          isDisabled: !_canSave,
          onPressed: _canSave ? _save : null,
          child: Text(l.chatSave),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuickSettingsCard(
              children: [
                QuickSettingsSwitchField(
                  label: l.chatPublicGroup,
                  hint: l.chatPublicGroupHint,
                  value: _public,
                  onChanged: (v) => setState(() => _public = v),
                ),
                // Anyone may join a public group: keeping invites to admins
                // means nothing there, so it shows off and cannot be changed.
                QuickSettingsSwitchField(
                  label: l.chatAdminInvite,
                  hint: l.chatAdminInviteHint,
                  value: !_public && _adminInvite,
                  onChanged: _public
                      ? null
                      : (v) => setState(() => _adminInvite = v),
                ),
              ],
            ),
            SizedBox(height: s.xl),
            Text(
              l.chatWhoCanPost,
              style: context.typography.bodyStrong.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: s.md),
            QuickSettingsSegmented<ChatSendScope>(
              value: _scope,
              options: {
                ChatSendScope.everyone: l.chatPostEveryone,
                ChatSendScope.admins: l.chatPostAdmins,
                ChatSendScope.selected: l.chatPostSelected,
              },
              onChanged: (v) => setState(() => _scope = v),
            ),
            if (_scope == ChatSendScope.selected) ...[
              SizedBox(height: s.lg),
              Text(
                l.chatPostSelectedHint,
                style: context.typography.bodySm.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              SizedBox(height: s.sm),
              Flexible(
                child: ChatCommitterPicker(
                  thread: widget.thread,
                  chat: widget.chat,
                  picked: _picked,
                  onToggle: (id) => setState(
                    () => _picked.contains(id)
                        ? _picked.remove(id)
                        : _picked.add(id),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

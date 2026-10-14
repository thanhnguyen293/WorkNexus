import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/navigation/open_account_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_presence.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_avatar.dart';
import 'chat_avatar_crop_dialog.dart';
import 'chat_avatar_upload_status.dart';
import 'chat_detail_row.dart';
import 'chat_editable_avatar.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';

export 'chat_profile_tap.dart';

class ChatUserProfileDialog extends ConsumerStatefulWidget {
  const ChatUserProfileDialog({
    super.key,
    required this.accountId,
    required this.userId,
    this.onViewProfile,
  });

  final String accountId;
  final int userId;
  final OpenAccountProfile? onViewProfile;

  static Future<void> show(
    BuildContext context, {
    required String accountId,
    required int userId,
    OpenAccountProfile? onViewProfile,
  }) => showDialog<void>(
    context: context,
    builder: (_) => ChatUserProfileDialog(
      accountId: accountId,
      userId: userId,
      onViewProfile: onViewProfile,
    ),
  );

  @override
  ConsumerState<ChatUserProfileDialog> createState() =>
      _ChatUserProfileDialogState();
}

class _ChatUserProfileDialogState extends ConsumerState<ChatUserProfileDialog> {
  bool _opening = false;

  Future<void> _message() async {
    setState(() => _opening = true);
    final navigator = Navigator.of(context);
    await openDirectChatWith(
      context,
      ref,
      accountId: widget.accountId,
      userId: widget.userId,
    );
    if (mounted) navigator.pop();
  }

  ChatAvatarUpload? _upload;
  bool get _uploading => _upload is ChatAvatarUploading;

  /// Picks a picture, lets the user crop it and makes it their avatar.
  Future<void> _changePicture() async {
    final files = await pickChatAttachments(imagesOnly: true);
    if (files.isEmpty || !mounted) return;
    final image = files.first.bytes;
    final crop = await ChatAvatarCropDialog.show(context, image);
    if (crop == null || !mounted) return;
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _upload = const ChatAvatarUploading());
    final result = await ref
        .read(chatControllerProvider)
        .setMyAvatar(widget.accountId, image, crop: crop);
    final upload = switch (result) {
      Ok() => const ChatAvatarUploaded(),
      Err(:final failure) => ChatAvatarUploadFailed(failure.message),
    };
    if (mounted) {
      setState(() => _upload = upload);
      return;
    }
    // Closed mid-upload: the outcome still gets told.
    showAppSnackOn(messenger, switch (upload) {
      ChatAvatarUploadFailed(:final reason) => l.chatMyAvatarFailed(reason),
      _ => l.chatMyAvatarUpdated,
    }, isError: upload is ChatAvatarUploadFailed);
  }

  void _viewProfile() {
    final navigator = Navigator.of(context);
    navigator.pop();
    widget.onViewProfile?.call(navigator.context, widget.accountId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final users = ref.watch(chatUsersProvider(widget.accountId)).value ?? {};
    final self = ref.watch(chatSelfUserIdProvider(widget.accountId)).value;
    final user = users[widget.userId];
    final name = chatUserName(context, users, widget.userId);
    return AppDialogFrame(
      title: l.chatUserProfile,
      maxWidth: context.sizes.dialogSm,
      actions: const [],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl5, 0, s.xl5, s.xl5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ChatEditableAvatar(
                editable: widget.userId == self && !_uploading,
                tooltip: l.chatChangeMyAvatar,
                onTap: _changePicture,
                child: ChatAvatar(
                  name: name,
                  imageUrl: user?.avatarUrl,
                  presence: chatPresenceOf(users, widget.userId),
                  verified: chatVerifiedBadge(context, users, widget.userId),
                  diameter: s.xl6 * 2,
                ),
              ),
            ),
            if (_upload case final upload?) ...[
              SizedBox(height: s.md),
              ChatAvatarUploadStatus(upload: upload),
            ],
            SizedBox(height: s.xl),
            SelectableText(
              name,
              textAlign: TextAlign.center,
              style: context.typography.titleLg.copyWith(color: c.textPrimary),
            ),
            if (user != null)
              Text(
                [
                  '@${user.account}',
                  if (user.status != null)
                    chatPresenceLabel(
                      context,
                      ChatPresence.fromStatus(user.status),
                    ),
                ].join('  ·  '),
                textAlign: TextAlign.center,
                style: context.typography.secondary.copyWith(
                  color: c.textSecondary,
                ),
              ),
            if (user?.role case final role?) ...[
              SizedBox(height: s.md),
              Center(
                child: TintedPill(
                  color: c.accent,
                  large: true,
                  pill: true,
                  label: chatRoleLabel(
                    context,
                    role,
                    serverNames:
                        ref
                            .watch(chatRoleNamesProvider(widget.accountId))
                            .value ??
                        const {},
                  ),
                ),
              ),
            ],
            if (user?.email case final email?)
              ChatDetailRow(
                icon: LucideIcons.mail300,
                label: l.chatEmail,
                value: email,
              ),
            if (user?.mobile case final mobile?)
              ChatDetailRow(
                icon: LucideIcons.smartphone300,
                label: l.chatMobile,
                value: mobile,
              ),
            if (user?.phone case final phone?)
              ChatDetailRow(
                icon: LucideIcons.phone300,
                label: l.chatPhone,
                value: phone,
              ),
            if (widget.userId == self) ...[
              SizedBox(height: s.xl5),
              if (widget.onViewProfile != null) ...[
                AppButton.outlinedNeutral(
                  icon: LucideIcons.userRound300,
                  onPressed: _viewProfile,
                  child: Text(l.chatViewFullProfile),
                ),
                SizedBox(height: s.sm),
              ],
              Tooltip(
                message: l.chatChangeMyAvatarHint,
                child: AppButton.outlinedNeutral(
                  icon: LucideIcons.camera300,
                  isLoading: _uploading,
                  onPressed: _uploading ? null : _changePicture,
                  child: Text(l.chatChangeMyAvatar),
                ),
              ),
            ],
            if (widget.userId != self) ...[
              SizedBox(height: s.xl5),
              AppButton.filled(
                icon: LucideIcons.messageSquare300,
                isLoading: _opening,
                onPressed: _opening ? null : _message,
                child: Text(l.chatSendMessage),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

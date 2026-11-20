import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/navigation/open_account_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_avatar.dart';
import 'chat_avatar_crop_dialog.dart';
import 'chat_avatar_upload_status.dart';
import 'chat_editable_avatar.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';
import 'chat_profile_details.dart';
import 'chat_profile_groups.dart';
import 'chat_profile_header.dart';
import 'chat_profile_tickets.dart';

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
    final isSelf = widget.userId == self;
    final user = users[widget.userId];
    final name = chatUserName(context, users, widget.userId);
    final person = (accountId: widget.accountId, userId: widget.userId);
    final diameter = s.xl6 * 2.2;
    return Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.sizes.dialogSm + s.xl6,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Semantics(
          container: true,
          label: l.chatUserProfile,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  // No bounce: overscrolling would drag the banner off the
                  // card's top edge and show the empty card behind it.
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: s.xl3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ChatProfileHeader(
                        name: name,
                        handle: user?.account,
                        presence: chatPresenceOf(users, widget.userId),
                        role: _roleLabel(user?.role),
                        avatarDiameter: diameter,
                        avatar: ChatEditableAvatar(
                          editable: isSelf && !_uploading,
                          tooltip: l.chatChangeMyAvatar,
                          onTap: _changePicture,
                          child: ChatAvatar(
                            name: name,
                            imageUrl: user?.avatarUrl,
                            verified: chatVerifiedBadge(
                              context,
                              users,
                              widget.userId,
                            ),
                            presence: chatPresenceOf(users, widget.userId),
                            diameter: diameter,
                          ),
                        ),
                      ),
                      if (_upload case final upload?) ...[
                        SizedBox(height: s.md),
                        ChatAvatarUploadStatus(upload: upload),
                      ],
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: s.xl5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ChatProfileDetails(person: person, user: user),
                            if (!isSelf && self != null)
                              ChatProfileGroups(person: person),
                            if (user != null)
                              ChatProfileTickets(
                                accountId: widget.accountId,
                                handle: user.account,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: c.border),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: s.xl5,
                  vertical: s.xl,
                ),
                child: isSelf
                    ? _SelfActions(
                        uploading: _uploading,
                        onViewProfile: widget.onViewProfile == null
                            ? null
                            : _viewProfile,
                        onChangePicture: _changePicture,
                      )
                    : AppButton.filled(
                        icon: LucideIcons.messageSquare300,
                        isLoading: _opening,
                        onPressed: _opening ? null : _message,
                        child: Text(l.chatSendMessage),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _roleLabel(String? role) => role == null
      ? null
      : chatRoleLabel(
          context,
          role,
          serverNames:
              ref.watch(chatRoleNamesProvider(widget.accountId)).value ??
              const {},
        );
}

/// Your own profile's actions: open the full profile, change your picture.
class _SelfActions extends StatelessWidget {
  const _SelfActions({
    required this.uploading,
    required this.onViewProfile,
    required this.onChangePicture,
  });

  final bool uploading;
  final VoidCallback? onViewProfile;
  final VoidCallback onChangePicture;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Row(
      spacing: context.spacing.md,
      children: [
        if (onViewProfile case final view?)
          Expanded(
            child: AppButton.outlinedNeutral(
              icon: LucideIcons.userRound300,
              onPressed: view,
              child: Text(l.chatViewFullProfile),
            ),
          ),
        Expanded(
          child: Tooltip(
            message: l.chatChangeMyAvatarHint,
            child: AppButton.filled(
              icon: LucideIcons.camera300,
              isLoading: uploading,
              onPressed: uploading ? null : onChangePicture,
              child: Text(l.chatChangeMyAvatar),
            ),
          ),
        ),
      ],
    );
  }
}

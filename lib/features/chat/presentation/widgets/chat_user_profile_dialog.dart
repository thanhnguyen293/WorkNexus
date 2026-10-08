import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_detail_row.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';

/// A chat user's profile — avatar, name, role and contact details — with a
/// button to message them directly.
class ChatUserProfileDialog extends ConsumerStatefulWidget {
  const ChatUserProfileDialog({
    super.key,
    required this.accountId,
    required this.userId,
  });

  final String accountId;
  final int userId;

  static Future<void> show(
    BuildContext context, {
    required String accountId,
    required int userId,
  }) => showDialog<void>(
    context: context,
    builder: (_) => ChatUserProfileDialog(accountId: accountId, userId: userId),
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final users = ref.watch(chatUsersProvider(widget.accountId)).value ?? {};
    final self = ref.watch(chatSelfUserIdProvider(widget.accountId)).value;
    final user = users[widget.userId];
    final name = chatUserName(context, users, widget.userId);
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: EdgeInsets.all(s.xl5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ChatAvatar(
                  name: name,
                  imageUrl: user?.avatarUrl,
                  diameter: s.xl6 * 2,
                ),
              ),
              SizedBox(height: s.xl),
              SelectableText(
                name,
                textAlign: TextAlign.center,
                style: context.typography.titleLg.copyWith(
                  color: c.textPrimary,
                ),
              ),
              if (user != null)
                Text(
                  '@${user.account}',
                  textAlign: TextAlign.center,
                  style: context.typography.secondary.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              if (user?.role case final role?) ...[
                SizedBox(height: s.md),
                Center(
                  child: TintedPill(color: c.accent, label: role),
                ),
              ],
              if (user?.email case final email?)
                ChatDetailRow(
                  icon: Icons.mail_outline,
                  label: l.chatEmail,
                  value: email,
                ),
              if (user?.mobile case final mobile?)
                ChatDetailRow(
                  icon: Icons.smartphone,
                  label: l.chatMobile,
                  value: mobile,
                ),
              if (user?.phone case final phone?)
                ChatDetailRow(
                  icon: Icons.call_outlined,
                  label: l.chatPhone,
                  value: phone,
                ),
              if (widget.userId != self) ...[
                SizedBox(height: s.xl5),
                AppButton.filled(
                  isLoading: _opening,
                  onPressed: _opening ? null : _message,
                  child: Text(l.chatSendMessage),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Makes [child] (an avatar or a sender name) open that user's profile.
class ChatProfileTap extends StatelessWidget {
  const ChatProfileTap({
    super.key,
    required this.accountId,
    required this.userId,
    required this.child,
  });

  final String accountId;
  final int userId;
  final Widget child;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => ChatUserProfileDialog.show(
        context,
        accountId: accountId,
        userId: userId,
      ),
      child: child,
    ),
  );
}

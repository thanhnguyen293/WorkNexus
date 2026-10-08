import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import '../providers/chat_providers.dart';
import 'chat_trust_dialog.dart';

/// A strip above the chat explaining why it is not live, with the action that
/// fixes it. Hidden while online.
class ChatStatusBanner extends ConsumerWidget {
  const ChatStatusBanner({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(chatStatusProvider(accountId)).asData?.value;
    final l = AppL10n.of(context);
    final c = context.colors;
    final connect = AppButton.outlinedNeutral(
      size: AppButtonSize.small,
      onPressed: () => ref.read(chatControllerProvider).connect(accountId),
      child: Text(l.chatConnect),
    );
    final (String? text, Color? tone, Widget? action) = switch (status) {
      null || ChatOnline() => (null, null, null),
      ChatConnecting() => (l.chatConnecting, c.textSecondary, null),
      ChatReconnecting(:final retryIn) => (
        l.chatReconnecting(retryIn.inSeconds),
        c.warning,
        null,
      ),
      ChatOffline() => (l.chatOffline, c.textSecondary, connect),
      ChatNeedsTrust() => (
        l.chatUntrusted,
        c.warning,
        AppButton.outlinedNeutral(
          size: AppButtonSize.small,
          onPressed: () => ChatTrustDialog.show(
            context,
            accountId: accountId,
            request: status,
          ),
          child: Text(l.chatReviewCertificate),
        ),
      ),
      ChatSignedOut(:final kicked, :final message) => (
        kicked ? l.chatKicked : l.chatSignedOut(message),
        c.error,
        connect,
      ),
    };
    if (text == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: Border(bottom: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xl3,
        vertical: context.spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: context.typography.secondary.copyWith(color: tone),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

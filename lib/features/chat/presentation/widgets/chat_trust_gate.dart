import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import 'chat_trust_dialog.dart';

/// The whole chat view while the chat server's certificate is unconfirmed.
/// Chat cannot connect before then, so a list and thread would only sit
/// empty; this says why and leads to the confirmation instead.
class ChatTrustGate extends StatelessWidget {
  const ChatTrustGate({
    super.key,
    required this.accountId,
    required this.request,
  });

  final String accountId;
  final ChatNeedsTrust request;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AppStateView.empty(
      icon: LucideIcons.shieldQuestion300,
      title: l.chatTrustGateTitle,
      message: l.chatTrustGateBody(request.host),
      action: AppButton.filled(
        size: AppButtonSize.small,
        icon: LucideIcons.shieldCheck300,
        onPressed: () => ChatTrustDialog.show(
          context,
          accountId: accountId,
          request: request,
        ),
        child: Text(l.chatReviewCertificate),
      ),
    );
  }
}

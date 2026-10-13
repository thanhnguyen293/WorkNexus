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
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_trust_preview.dart';
import 'chat_certificate_card.dart';
import 'chat_trust_reasons.dart';

/// Trust-on-first-use: explains why the chat server's self-signed
/// certificate needs confirming, shows it, and pins its fingerprint when the
/// user accepts. Chat cannot connect until then.
class ChatTrustDialog extends ConsumerStatefulWidget {
  const ChatTrustDialog({
    super.key,
    required this.accountId,
    required this.request,
  });

  final String accountId;
  final ChatNeedsTrust request;

  static Future<void> show(
    BuildContext context, {
    required String accountId,
    required ChatNeedsTrust request,
  }) => showDialog(
    context: context,
    builder: (_) => ChatTrustDialog(accountId: accountId, request: request),
  );

  @override
  ConsumerState<ChatTrustDialog> createState() => _ChatTrustDialogState();
}

class _ChatTrustDialogState extends ConsumerState<ChatTrustDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _trust() async {
    // The debug preview's certificate is made up: pinning it would replace
    // the account's real one, so trusting it only ends the preview.
    final preview = ref.read(chatTrustPreviewProvider.notifier);
    if (preview.state == widget.request) {
      preview.state = null;
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(chatControllerProvider)
        .trust(widget.accountId, widget.request.fingerprint);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        setState(() {
          _busy = false;
          _error = AppL10n.of(context).chatActionFailed(failure.message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final error = _error;
    return AppDialogFrame(
      title: l.chatTrustTitle,
      leadingIcon: LucideIcons.shieldQuestion300,
      maxWidth: context.sizes.dialogMd,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.chatTrustLater),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          icon: LucideIcons.shieldCheck300,
          isLoading: _busy,
          onPressed: _busy ? null : _trust,
          child: Text(l.chatTrustAction),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.chatTrustBody(widget.request.host),
              style: context.typography.paragraph.copyWith(
                color: c.textSecondary,
              ),
            ),
            SizedBox(height: s.xl3),
            const ChatTrustReasons(),
            SizedBox(height: s.xl3),
            ChatCertificateCard(request: widget.request),
            if (error != null) ...[
              SizedBox(height: s.xl),
              AppInlineNote(text: error, isError: true),
            ],
          ],
        ),
      ),
    );
  }
}

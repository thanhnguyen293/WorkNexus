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

/// Trust-on-first-use: shows the self-signed certificate of the chat server
/// and pins its fingerprint when the user accepts.
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
    final mono = context.typography.mono.copyWith(color: c.textPrimary);
    final label = context.typography.captionStrong.copyWith(
      color: c.textSecondary,
    );
    return AppDialogFrame(
      title: l.chatTrustTitle,
      maxWidth: context.sizes.dialogMd,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.cancel),
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
            Text(l.chatTrustFingerprint, style: label),
            SizedBox(height: s.xs),
            SelectableText(widget.request.fingerprint, style: mono),
            SizedBox(height: s.xl),
            Text(l.chatTrustIssuer, style: label),
            SizedBox(height: s.xs),
            SelectableText(widget.request.issuer, style: mono),
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

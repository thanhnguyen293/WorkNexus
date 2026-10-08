import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
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
    final l = AppL10n.of(context);
    final mono = context.typography.bodySm.copyWith(
      color: c.textPrimary,
      fontFamily: 'monospace',
    );
    final label = context.typography.captionStrong.copyWith(
      color: c.textSecondary,
    );
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      title: Text(
        l.chatTrustTitle,
        style: context.typography.title.copyWith(color: c.textPrimary),
      ),
      content: SizedBox(
        width: 440,
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
            SizedBox(height: context.spacing.xl3),
            Text(l.chatTrustFingerprint, style: label),
            SizedBox(height: context.spacing.xs),
            SelectableText(widget.request.fingerprint, style: mono),
            SizedBox(height: context.spacing.xl),
            Text(l.chatTrustIssuer, style: label),
            SizedBox(height: context.spacing.xs),
            SelectableText(widget.request.issuer, style: mono),
            if (_error != null) ...[
              SizedBox(height: context.spacing.xl),
              Text(
                _error!,
                style: context.typography.bodySm.copyWith(color: c.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton.textNeutral(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        SizedBox(width: context.spacing.md),
        AppButton.filled(
          isLoading: _busy,
          onPressed: _busy ? null : _trust,
          child: Text(l.chatTrustAction),
        ),
      ],
    );
  }
}

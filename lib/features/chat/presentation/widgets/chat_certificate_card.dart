import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_connection_status.dart';

/// Bytes of the fingerprint per line: four even lines that are easy to read
/// out and compare with what an administrator sends.
const int _kBytesPerLine = 8;

/// The certificate the chat server presented: who it is for, who issued it
/// and its SHA-256 fingerprint, which can be copied to send for checking.
class ChatCertificateCard extends StatelessWidget {
  const ChatCertificateCard({super.key, required this.request});

  final ChatNeedsTrust request;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border, width: context.borders.hairline),
      ),
      child: Padding(
        padding: EdgeInsets.all(s.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(label: l.chatTrustServer, value: request.host),
            SizedBox(height: s.md),
            _Field(
              label: l.chatTrustSubject,
              value: certificateName(request.subject),
            ),
            SizedBox(height: s.md),
            _Field(
              label: l.chatTrustIssuer,
              value: certificateName(request.issuer),
            ),
            SizedBox(height: s.lg),
            Row(
              children: [
                Expanded(child: _Label(l.chatTrustFingerprint)),
                AppIconButton(
                  icon: LucideIcons.copy300,
                  tooltip: l.chatTrustCopyFingerprint,
                  size: AppIconButtonSize.small,
                  onPressed: () => _copy(context),
                ),
              ],
            ),
            SelectableText(
              fingerprintLines(request.fingerprint),
              style: context.typography.mono.copyWith(
                color: c.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final copied = AppL10n.of(context).chatTrustFingerprintCopied;
    await Clipboard.setData(ClipboardData(text: request.fingerprint));
    if (context.mounted) showAppSnack(context, copied);
  }
}

/// [fingerprint] (`AB:CD:…`) broken into lines of [_kBytesPerLine] bytes.
String fingerprintLines(String fingerprint) {
  final bytes = fingerprint.split(':');
  return [
    for (var i = 0; i < bytes.length; i += _kBytesPerLine)
      bytes.skip(i).take(_kBytesPerLine).join(':'),
  ].join('\n');
}

/// The common name in a certificate's distinguished name (`/C=VN/CN=host`
/// or `CN=host, O=…`), or the whole name when it has none.
String certificateName(String distinguishedName) {
  final cn = RegExp(r'CN=([^/,]+)').firstMatch(distinguishedName)?.group(1);
  return cn?.trim() ?? distinguishedName;
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Label(label),
      SizedBox(height: context.spacing.xxs),
      SelectableText(
        value,
        style: context.typography.body.copyWith(
          color: context.colors.textPrimary,
        ),
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.typography.captionStrong.copyWith(
      color: context.colors.textSecondary,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/opencode_credential.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/fonts.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../opencode_key_controller.dart';
import '../opencode_key_dialog.dart';
import 'opencode_unlink_dialog.dart';

/// One provider OpenCode holds credentials for: its id, how it authenticates,
/// and — for API keys — a masked tail plus the actions to replace or unlink it.
/// OAuth logins are read-only here; only the CLI can refresh those.
class OpenCodeCredentialRow extends ConsumerWidget {
  const OpenCodeCredentialRow({super.key, required this.credential});

  final OpenCodeCredential credential;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final isApiKey = credential.type == OpenCodeAuthType.api;
    final busy = ref.watch(openCodeKeyControllerProvider).busy;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      credential.providerId,
                      style: context.typography.bodyStrong.copyWith(
                        color: c.textPrimary,
                        fontFamily: kMonoFont,
                      ),
                    ),
                    SizedBox(width: context.spacing.md),
                    TintedPill(
                      color: isApiKey ? c.accent : c.textTertiary,
                      label: _typeLabel(l, credential.type),
                      pill: true,
                    ),
                  ],
                ),
                SizedBox(height: context.spacing.xxs),
                Text(
                  isApiKey
                      ? (credential.keyPreview ?? '')
                      : l.openCodeOauthReadOnly,
                  style: context.typography.caption.copyWith(
                    color: c.textTertiary,
                    fontFamily: isApiKey ? kMonoFont : null,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.spacing.lg),
          if (isApiKey)
            AppButton.outlinedNeutral(
              size: AppButtonSize.small,
              onPressed: busy
                  ? null
                  : () => OpenCodeKeyDialog.show(
                      context,
                      providerId: credential.providerId,
                    ),
              child: Text(l.openCodeChangeKey),
            ),
          SizedBox(width: context.spacing.sm),
          AppButton.textNeutral(
            size: AppButtonSize.small,
            onPressed: busy
                ? null
                : () => OpenCodeUnlinkDialog.show(
                    context,
                    providerId: credential.providerId,
                  ),
            child: Text(l.openCodeUnlink),
          ),
        ],
      ),
    );
  }

  String _typeLabel(AppL10n l, OpenCodeAuthType type) => switch (type) {
    OpenCodeAuthType.api => l.openCodeAuthTypeApi,
    OpenCodeAuthType.oauth => l.openCodeAuthTypeOauth,
    OpenCodeAuthType.wellKnown ||
    OpenCodeAuthType.unknown => l.openCodeAuthTypeOther,
  };
}

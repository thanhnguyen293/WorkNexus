import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/domain/entities/account.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../features/connections/presentation/connect_account_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Banner shown at the top of the viewport when an account's session has expired
/// (specs F1). Read-only cached data stays browsable; clicking "Re-authenticate"
/// opens the account connection dialog.
class AuthExpiredBanner extends StatelessWidget {
  const AuthExpiredBanner({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.sm),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: c.warning.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertTriangle300, size: 16, color: c.warning),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              l.sessionExpiredBanner(account.providerType.displayName),
              style: context.typography.bodySm.copyWith(color: c.textPrimary),
            ),
          ),
          SizedBox(width: s.md),
          AppButton.outlinedNeutral(
            size: AppButtonSize.small,
            onPressed: () => ConnectAccountDialog.show(context),
            child: Text(l.reauthenticate),
          ),
        ],
      ),
    );
  }
}

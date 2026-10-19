import 'package:flutter/widgets.dart';

import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/certificate_problem.dart';

/// Asks whether to trust a site whose certificate is refused, saying which
/// site, what is wrong with the certificate and what trusting means.
abstract final class CertificateTrustPrompt {
  /// True only when the user chooses to trust [origin] with [problem] ([error]
  /// is the raw code, shown when the problem has no words of its own).
  static Future<bool> ask(
    BuildContext context, {
    required String origin,
    required CertificateProblem problem,
    required String error,
  }) {
    final l = AppL10n.of(context);
    final reason = switch (problem) {
      CertificateProblem.dates => l.certReasonDates,
      CertificateProblem.name => l.certReasonName,
      CertificateProblem.authority => l.certReasonAuthority,
      CertificateProblem.other => l.certReasonOther(error),
    };
    return AppConfirmDialog.show(
      context,
      title: l.certPromptTitle,
      message: l.certPromptMessage(origin, reason),
      confirmLabel: l.certTrust,
    );
  }
}

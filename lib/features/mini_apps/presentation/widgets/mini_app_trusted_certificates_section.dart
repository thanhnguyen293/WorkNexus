import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/certificate_problem.dart';
import '../providers/trusted_certificates_controller.dart';

/// The sites whose invalid certificate the user chose to trust, each with a
/// button to forget it, and one to forget them all.
class MiniAppTrustedCertificatesSection extends ConsumerWidget {
  const MiniAppTrustedCertificatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final items = ref.watch(trustedCertificatesProvider).asData?.value ?? [];
    final controller = ref.read(trustedCertificatesProvider.notifier);
    if (items.isEmpty) {
      return Text(
        l.miniAppTrustedCertsEmpty,
        style: context.typography.caption.copyWith(color: c.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: s.md,
      children: [
        for (final item in items)
          Row(
            spacing: s.lg,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.origin,
                      style: context.typography.body.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      _reason(l, item.error),
                      style: context.typography.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppButton.outlinedNeutral(
                size: AppButtonSize.small,
                icon: LucideIcons.x300,
                onPressed: () => controller.forget(item),
                child: Text(l.miniAppTrustedCertForget),
              ),
            ],
          ),
        if (items.length > 1)
          AppButton.error(
            size: AppButtonSize.small,
            icon: LucideIcons.trash2300,
            onPressed: controller.forgetAll,
            child: Text(l.miniAppTrustedCertsForgetAll),
          ),
      ],
    );
  }

  /// The problem in a few words: the same ones the prompt used.
  static String _reason(AppL10n l, String error) =>
      switch (CertificateProblem.of(error)) {
        CertificateProblem.dates => l.certReasonDates,
        CertificateProblem.name => l.certReasonName,
        CertificateProblem.authority => l.certReasonAuthority,
        CertificateProblem.other => l.certReasonOther(error),
      };
}

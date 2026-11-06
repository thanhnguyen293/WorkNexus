import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/trusted_certificate.dart';
import '../providers/trusted_certificates_controller.dart';
import '../util/mini_app_certificate_guard.dart';

/// The edit dialog's switch to trust the certificate of the site in [url]
/// without being asked: the same trust the prompt records, set up front.
/// Shown only where the app can act on it (see
/// [MiniAppCertificateGuard.supported]) and for a secure address.
class MiniAppCertificateSection extends ConsumerWidget {
  const MiniAppCertificateSection({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = MiniAppCertificateGuard.originOf(Uri.tryParse(url.trim()));
    if (!MiniAppCertificateGuard.supported || origin == null) {
      return const SizedBox.shrink();
    }
    final l = AppL10n.of(context);
    final controller = ref.read(trustedCertificatesProvider.notifier);
    final trusted = ref
        .watch(trustedCertificatesProvider)
        .asData
        ?.value
        .where((item) => item.origin == origin)
        .firstOrNull;
    Future<void> change(bool on) async {
      final messenger = ScaffoldMessenger.of(context);
      final failed = l.miniAppTrustedCertsSaveFailed;
      final done = on
          ? await controller.trust(origin, kTrustedByChoice)
          : trusted == null
          ? const Ok<void>(null)
          : await controller.forget(trusted);
      if (done.isErr) showAppSnackOn(messenger, failed, isError: true);
    }

    return QuickSettingsSwitchField(
      label: l.miniAppCertAlwaysTrust,
      hint: l.miniAppCertAlwaysTrustHint,
      value: trusted != null,
      onChanged: change,
    );
  }
}

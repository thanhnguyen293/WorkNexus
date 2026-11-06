import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/certificate_fingerprint.dart';
import '../../domain/value_objects/certificate_problem.dart';
import '../providers/mini_app_providers.dart';
import '../providers/trusted_certificates_controller.dart';
import 'mini_app_certificate_prompt.dart';

/// How a mini app's page answers a server whose certificate the system
/// refuses, on macOS, where the web view asks the app about every server it
/// meets: the page itself or what it calls, such as ZenTao's chat server with
/// its self-signed certificate.
///
/// A certificate the user already accepted (pinned by the app's chat, or
/// trusted here before for that host) goes through. Any other refused one is
/// asked about once, through [CertificateTrustPrompt], with its fingerprint;
/// trusted, it is kept for that host (Settings lists it, to forget it), and
/// only that certificate is accepted. A certificate the system accepts gets
/// no answer of ours.
///
/// One per web view: what the user declined is not asked again until the page
/// is opened anew.
class MiniAppServerTrust {
  MiniAppServerTrust({required this.context, required this.ref});

  final BuildContext Function() context;
  final WidgetRef ref;

  /// Questions under way, by fingerprint: the same certificate met again
  /// meanwhile (another port, another request) waits for the one answer.
  final _asking = <String, Future<bool>>{};
  final _declined = <String>{};

  static final _proceed = ServerTrustAuthResponse(
    action: ServerTrustAuthResponseAction.PROCEED,
  );
  static final _cancel = ServerTrustAuthResponse();

  Future<ServerTrustAuthResponse?> answer(URLProtectionSpace space) async {
    final certificate = space.sslCertificate?.x509Certificate;
    final der = certificate?.encoded;
    if (certificate == null || der == null) return null;
    final host = space.host;
    if (await ref.read(isTrustedServerCertificateProvider)(
      host: host,
      der: der,
    )) {
      return _proceed;
    }
    // Only a refusal the user may overrule is asked about; a certificate the
    // system accepts, or one it refuses outright, keeps its answer.
    if (space.sslError?.code != SslErrorType.RECOVERABLE_TRUST_FAILURE) {
      return null;
    }
    final fingerprint = certificateFingerprint(der);
    if (_declined.contains(fingerprint)) return _cancel;
    final asking = _asking.putIfAbsent(
      fingerprint,
      () => _ask(
        origin: 'https://$host:${space.port}',
        fingerprint: fingerprint,
        selfSigned:
            certificate.issuerDistinguishedName ==
            certificate.subjectDistinguishedName,
      ),
    );
    final yes = await asking;
    _asking.removeWhere((key, _) => key == fingerprint);
    if (!yes) _declined.add(fingerprint);
    return yes ? _proceed : _cancel;
  }

  Future<bool> _ask({
    required String origin,
    required String fingerprint,
    required bool selfSigned,
  }) async {
    final ctx = context();
    if (!ctx.mounted) return false;
    // The same codes the Windows web view reports, so Settings words both.
    final error = selfSigned
        ? 'net::ERR_CERT_AUTHORITY_INVALID'
        : 'net::ERR_CERT_INVALID';
    final yes = await CertificateTrustPrompt.ask(
      ctx,
      origin: origin,
      problem: CertificateProblem.of(error),
      error: error,
      fingerprint: fingerprint,
    );
    if (!yes) return false;
    final saved = await ref
        .read(trustedCertificatesProvider.notifier)
        .trust(origin, error, fingerprint: fingerprint);
    if (saved case Err(:final failure)) {
      // Trusted for now all the same: the user said so.
      appTalker.warning('Trusting $origin failed: ${failure.message}');
      final after = context();
      if (after.mounted) {
        showAppSnack(
          after,
          AppL10n.of(after).certTrustSaveFailed,
          isError: true,
        );
      }
    }
    return true;
  }
}

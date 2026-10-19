import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../domain/value_objects/certificate_problem.dart';
import '../providers/trusted_certificates_controller.dart';
import 'mini_app_certificate_prompt.dart';

/// What happens in a mini app's page when its site's certificate is refused.
///
/// The Windows web view tells the app nothing of it: it shows its own warning
/// page, and no error or load-finished event follows. So once a page has
/// stopped loading without finishing, the guard looks at it: if it is that
/// warning page, it reads the error from it. A site the user already trusted
/// is let through (the web view is told to ignore certificate errors and the
/// page is loaded again); any other is asked about through
/// [CertificateTrustPrompt], and trusted only if the user says so. Trust is
/// kept by the app, not by the web view, which forgets such a choice after a
/// while and would ask again.
///
/// Trust is for the site, not for one problem: while the page shown is a
/// trusted site's, the web view ignores certificate errors of every kind
/// (the page's own requests, such as the blocks a dashboard fills in after
/// loading, meet the same certificate and would fail otherwise). That covers
/// the other sites the page itself calls, too. It stops when the web view goes
/// to a site that is not trusted; forgetting a site in Settings undoes it.
///
/// One per web view: it holds that page's own state.
class MiniAppCertificateGuard {
  MiniAppCertificateGuard({required this.context, required this.ref});

  final BuildContext Function() context;
  final WidgetRef ref;

  /// Windows only: the other web views report the error themselves.
  static bool get supported => defaultTargetPlatform == TargetPlatform.windows;

  /// How long a page that stopped loading has to finish before it is looked at.
  static const settleDelay = Duration(milliseconds: 400);

  /// How many times in a row a trusted site is let through; a page that still
  /// shows the warning after that has another problem.
  static const maxReloads = 2;

  Timer? _settle;
  bool _asking = false;
  bool _ignoring = false;
  int _reloads = 0;

  /// A new load starts for [url]: the page that was about to be looked at is
  /// gone, and certificate errors are ignored only if the site is a trusted
  /// one — before its first request, if the call gets there in time (else the
  /// warning page appears and [onProgress] sorts it out).
  Future<void> onLoadStart(InAppWebViewController web, Uri? url) async {
    _settle?.cancel();
    if (!supported) return;
    try {
      final origin = originOf(url);
      final trusted =
          origin != null &&
          await ref
              .read(trustedCertificatesProvider.notifier)
              .isOriginTrusted(origin);
      if (trusted == _ignoring) return;
      _ignoring = trusted;
      await _ignoreErrors(web, ignore: trusted);
    } on Object catch (e, st) {
      appTalker.handle(e, st, 'Mini app certificate setting failed');
    }
  }

  /// The page reports its progress; at 100 with no load-finished following, it
  /// is looked at.
  void onProgress(InAppWebViewController web, int percent) {
    if (!supported || percent < 100) return;
    _settle?.cancel();
    _settle = Timer(settleDelay, () => unawaited(_look(web)));
  }

  /// The page finished loading: it is not the warning page, and the count of
  /// reloads starts over.
  void onLoadStop() {
    _settle?.cancel();
    _reloads = 0;
  }

  void dispose() => _settle?.cancel();

  Future<void> _look(InAppWebViewController web) async {
    try {
      final error = await _warningError(web);
      if (error == null || !CertificateProblem.isCertificateError(error)) {
        return;
      }
      final origin = originOf(await web.getUrl());
      if (origin == null) return;
      final trusted = ref.read(trustedCertificatesProvider.notifier);
      if (await trusted.isOriginTrusted(origin)) {
        await _allowAndReload(web);
        return;
      }
      if (_asking) return;
      _asking = true;
      try {
        final ctx = context();
        if (!ctx.mounted) return;
        final yes = await CertificateTrustPrompt.ask(
          ctx,
          origin: origin,
          problem: CertificateProblem.of(error),
          error: error,
        );
        if (!yes) return;
        await trusted.trust(origin, error);
        await _allowAndReload(web);
      } finally {
        _asking = false;
      }
    } on Object catch (e, st) {
      // Looking at the page is a courtesy: the warning page stays as it is.
      appTalker.handle(e, st, 'Mini app certificate check failed');
    }
  }

  /// The error code shown on the web view's warning page (`net::ERR_CERT_…`),
  /// or null when the page is not that page.
  Future<String?> _warningError(InAppWebViewController web) async {
    final result = await web.evaluateJavascript(source: _probe);
    final error = result is String ? result.trim() : null;
    return error == null || error.isEmpty ? null : error;
  }

  /// Ignore certificate errors from now on (until the web view leaves the
  /// site, see [onLoadStart]) and load the page again.
  Future<void> _allowAndReload(InAppWebViewController web) async {
    if (_reloads >= maxReloads) return;
    _reloads++;
    _ignoring = true;
    await _ignoreErrors(web, ignore: true);
    await web.reload();
  }

  static Future<void> _ignoreErrors(
    InAppWebViewController web, {
    required bool ignore,
  }) => web.callDevToolsProtocolMethod(
    methodName: 'Security.setIgnoreCertificateErrors',
    parameters: {'ignore': ignore},
  );

  /// `https://host:port` of [url] (the port spelled out, 443 when the address
  /// has none), or null for anything but a secure address.
  static String? originOf(Uri? url) {
    if (url == null || url.scheme != 'https' || url.host.isEmpty) return null;
    final port = url.hasPort ? url.port : 443;
    return 'https://${url.host}:$port';
  }

  /// Run in the page: the error code when it is the web view's warning page
  /// (an address of its own, `chrome-error:`), else nothing.
  static const _probe = '''
(function () {
  if (location.protocol !== 'chrome-error:') return '';
  var el = document.querySelector('.error-code');
  return el ? el.textContent : '';
})()
''';
}

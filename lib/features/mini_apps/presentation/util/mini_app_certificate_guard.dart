import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/trusted_certificate.dart';
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
/// the other sites the page itself calls, too. Whether errors are ignored is
/// settled in [beforeRequest], which holds every main-frame document request
/// (a redirect too) until it is: a site that is not trusted never goes out
/// while errors are still ignored for the one before. Forgetting the site
/// shown stops it at once ([onTrustChanged]).
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

  InAppWebViewController? _web;
  Timer? _settle;
  bool _asking = false;
  bool _ignoring = false;
  int _reloads = 0;

  /// The origin of the page the web view shows or is going to.
  String? _origin;

  void attach(InAppWebViewController web) => _web = web;

  /// A document request of the page is about to leave (the web view waits for
  /// the answer). For the main frame, certificate errors are ignored from now
  /// on only if [action]'s site is trusted, and that is in place before the
  /// request is let go. Frames inside the page keep what their page has.
  Future<NavigationActionPolicy> beforeRequest(NavigationAction action) async {
    final web = _web;
    if (!supported || web == null || !action.isForMainFrame) {
      return NavigationActionPolicy.ALLOW;
    }
    final origin = originOf(action.request.url);
    _origin = origin;
    final trusted = origin != null && await _isTrusted(origin);
    if (trusted == _ignoring) return NavigationActionPolicy.ALLOW;
    try {
      await _ignoreErrors(web, ignore: trusted);
      _ignoring = trusted;
      return NavigationActionPolicy.ALLOW;
    } on Object catch (e, st) {
      appTalker.handle(e, st, 'Mini app certificate setting failed');
      // Errors still ignored for a site that is not trusted: better not to go
      // than to go unchecked.
      return trusted
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL;
    }
  }

  /// The list of trusted sites changed: if the site shown is no longer on it,
  /// its certificate errors stop being ignored now, not at the next page.
  Future<void> onTrustChanged(List<TrustedCertificate> trusted) async {
    final web = _web;
    final origin = _origin;
    if (!_ignoring || web == null) return;
    if (origin != null && trusted.any((item) => item.origin == origin)) return;
    try {
      await _ignoreErrors(web, ignore: false);
      _ignoring = false;
    } on Object catch (e, st) {
      appTalker.handle(e, st, 'Mini app certificate setting failed');
    }
  }

  /// A new page starts loading: the one that was about to be looked at is gone.
  void onLoadStart() => _settle?.cancel();

  /// The page reports its progress; at 100 with no load-finished following, it
  /// is looked at.
  void onProgress(int percent) {
    final web = _web;
    if (!supported || web == null || percent < 100) return;
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

  Future<bool> _isTrusted(String origin) async {
    try {
      return await ref
          .read(trustedCertificatesProvider.notifier)
          .isTrusted(origin);
    } on Object catch (e, st) {
      // The list could not be read: nothing counts as trusted.
      appTalker.handle(e, st, 'Reading trusted certificates failed');
      return false;
    }
  }

  Future<void> _look(InAppWebViewController web) async {
    try {
      final error = await _warningError(web);
      if (error == null || !CertificateProblem.isCertificateError(error)) {
        return;
      }
      final origin = originOf(await web.getUrl());
      if (origin == null) return;
      if (await _isTrusted(origin)) {
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
        final saved = await ref
            .read(trustedCertificatesProvider.notifier)
            .trust(origin, error);
        if (saved case Err(:final failure)) {
          appTalker.warning('Trusting $origin failed: ${failure.message}');
          final after = context();
          if (after.mounted) {
            showAppSnack(
              after,
              AppL10n.of(after).certTrustSaveFailed,
              isError: true,
            );
          }
          return;
        }
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
  /// site, see [beforeRequest]) and load the page again.
  Future<void> _allowAndReload(InAppWebViewController web) async {
    if (_reloads >= maxReloads) return;
    _reloads++;
    await _ignoreErrors(web, ignore: true);
    _ignoring = true;
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

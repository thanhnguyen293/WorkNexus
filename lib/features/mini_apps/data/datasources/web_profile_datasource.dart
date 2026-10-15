import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// The web profile every mini app shares (WebView2's user data folder), reached
/// through the DevTools protocol of a short-lived hidden web view: it shares
/// the profile, and flutter_inappwebview has no other way to clear it on
/// Windows.
class WebProfileDatasource {
  const WebProfileDatasource();

  bool get supported => defaultTargetPlatform == TargetPlatform.windows;

  Future<void> clearCache() =>
      _run((web) => _call(web, 'Network.clearBrowserCache'));

  /// Every kind of storage [origins] keep, cookies included.
  Future<void> clearOrigins(Iterable<String> origins) => _run((web) async {
    for (final origin in origins.toSet()) {
      await _call(web, 'Storage.clearDataForOrigin', {
        'origin': origin,
        'storageTypes': 'all',
      });
    }
  });

  Future<void> clearCookies() =>
      _run((web) => _call(web, 'Network.clearBrowserCookies'));

  static Future<void> _call(
    InAppWebViewController web,
    String method, [
    Map<String, dynamic> parameters = const {},
  ]) => web.callDevToolsProtocolMethod(
    methodName: method,
    parameters: parameters,
  );

  /// Runs [job] against a hidden blank page, then closes it.
  Future<void> _run(
    Future<void> Function(InAppWebViewController web) job,
  ) async {
    final ready = Completer<InAppWebViewController>();
    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('about:blank')),
      onLoadStop: (web, _) {
        if (!ready.isCompleted) ready.complete(web);
      },
      onReceivedError: (web, _, _) {
        if (!ready.isCompleted) ready.complete(web);
      },
    );
    try {
      await headless.run();
      await job(await ready.future.timeout(const Duration(seconds: 15)));
    } finally {
      await headless.dispose();
    }
  }
}

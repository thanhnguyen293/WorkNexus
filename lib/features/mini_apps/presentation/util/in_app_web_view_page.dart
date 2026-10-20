import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'mini_app_page_capability.dart';
import 'mini_app_page_driver.dart';
import 'web_view_frame_rate.dart';

/// A mini app's page in flutter_inappwebview's web view (Windows, macOS).
class InAppWebViewMiniAppPage implements MiniAppPageDriver, MiniAppPageBridge {
  const InAppWebViewMiniAppPage(this.web);

  final InAppWebViewController web;

  @override
  void addHandler(String name, dynamic Function(List<dynamic> args) handler) =>
      web.addJavaScriptHandler(handlerName: name, callback: handler);

  @override
  Future<Uri?> currentUrl() => web.getUrl();

  @override
  void load(String url) =>
      unawaited(web.loadUrl(urlRequest: URLRequest(url: WebUri(url))));

  @override
  void reload() => unawaited(web.reload());

  /// Each web view skips the cache its own way, and calling the other one's
  /// throws: WebView2 (Windows) through the DevTools protocol, WKWebView
  /// (macOS) as a reload from the origin.
  @override
  void hardReload() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        unawaited(
          web.callDevToolsProtocolMethod(
            methodName: 'Page.reload',
            parameters: {'ignoreCache': true},
          ),
        );
      case TargetPlatform.macOS:
        unawaited(web.reloadFromOrigin());
      default:
        unawaited(web.reload());
    }
  }

  @override
  void stop() => unawaited(web.stopLoading());

  @override
  void goBack() => unawaited(web.goBack());

  @override
  void goForward() => unawaited(web.goForward());

  @override
  void openDevTools() => unawaited(web.openDevTools());

  @override
  Future<bool> canGoBack() => web.canGoBack();

  @override
  Future<bool> canGoForward() => web.canGoForward();

  /// Through the DevTools protocol, which only WebView2 (Windows) has.
  @override
  Future<void> setColorScheme(Brightness brightness) =>
      web.callDevToolsProtocolMethod(
        methodName: 'Emulation.setEmulatedMedia',
        parameters: {
          'features': [
            {
              'name': 'prefers-color-scheme',
              'value': brightness == Brightness.dark ? 'dark' : 'light',
            },
          ],
        },
      );

  @override
  Future<void> setSuspended(bool suspended) =>
      suspended ? web.pause() : web.resume();

  @override
  Future<void> setFrameRateLimit(int framesPerSecond) =>
      setWebViewFrameRateLimit(web, framesPerSecond);
}

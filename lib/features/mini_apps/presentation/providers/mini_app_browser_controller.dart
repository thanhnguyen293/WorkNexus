import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/mini_app_links.dart';
import 'mini_app_browser_state.dart';
import 'mini_app_providers.dart';

/// The browsing of one mini app's page: what the toolbar and the cover show
/// ([MiniAppBrowserState]) and the commands that drive the web view. The view
/// only draws it, and hands the web view over once it exists ([attach]).
///
/// It also decides where the page starts — the link that opened the app, else
/// the page it was last on, else its own address — and follows later links
/// aimed at it.
class MiniAppBrowserController extends Notifier<MiniAppBrowserState> {
  MiniAppBrowserController(this.appId);

  final String appId;

  InAppWebViewController? _web;
  int _handledSeq = 0;

  @override
  MiniAppBrowserState build() {
    final app = ref
        .read(miniAppsProvider)
        .asData
        ?.value
        .where((a) => a.id == appId)
        .firstOrNull;
    final pending = ref.read(miniAppNavigationProvider);
    final claimed = pending != null && pending.id == appId;
    if (claimed) _handledSeq = pending.seq;
    final initialUrl = claimed ? pending.url : app?.lastUrl ?? app?.url ?? '';
    ref.listen<MiniAppNavigation?>(miniAppNavigationProvider, (_, next) {
      if (next == null || next.id != appId || next.seq == _handledSeq) return;
      _handledSeq = next.seq;
      load(next.url);
    });
    return MiniAppBrowserState(initialUrl: initialUrl, address: initialUrl);
  }

  void attach(InAppWebViewController web) => _web = web;

  void load(String url) =>
      _web?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));

  void reload() => _web?.reload();

  /// A reload that skips the cache. Each web view offers it its own way, and
  /// calling the other one's throws: WebView2 (Windows) through the DevTools
  /// protocol, WKWebView (macOS) as a reload from the origin.
  void hardReload() {
    final web = _web;
    if (web == null) return;
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

  void stop() => _web?.stopLoading();

  void goBack() {
    if (state.canGoBack) _web?.goBack();
  }

  void goForward() {
    if (state.canGoForward) _web?.goForward();
  }

  void openDevTools() => _web?.openDevTools();

  // ---- What the web view reports ----

  void onLoadStart() {
    if (state.loadError != null) state = state.copyWith(loadError: null);
  }

  void onProgress(double progress) =>
      state = state.copyWith(progress: progress);

  void onError(String message) => state = state.copyWith(loadError: message);

  /// The page moved to [url]: show it, keep it to reopen next time (web pages
  /// only) and refresh what back / forward can do.
  Future<void> onVisited(WebUri url) async {
    state = state.copyWith(address: url.toString());
    if (url.scheme == 'http' || url.scheme == 'https') {
      unawaited(
        ref
            .read(miniAppControllerProvider.notifier)
            .rememberPage(appId, url.toString()),
      );
    }
    final web = _web;
    if (web == null) return;
    final back = await web.canGoBack();
    final forward = await web.canGoForward();
    if (!ref.mounted) return;
    state = state.copyWith(canGoBack: back, canGoForward: forward);
  }
}

final miniAppBrowserProvider = NotifierProvider.autoDispose
    .family<MiniAppBrowserController, MiniAppBrowserState, String>(
      MiniAppBrowserController.new,
    );

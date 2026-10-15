import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/mini_app_links.dart';
import '../util/web_view_frame_rate.dart';
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

  /// The page to reopen next time, not kept yet: single-page sites move on
  /// every click, and each save redraws every mini app, so it waits for the
  /// page to settle ([saveDelay]) or the app to close.
  String? _unsaved;
  Timer? _saveTimer;

  static const saveDelay = Duration(seconds: 3);

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
    if (claimed) _consume(pending);
    final initialUrl = claimed ? pending.url : app?.lastUrl ?? app?.url ?? '';
    // Kept here: a disposing provider may not read others.
    final apps = ref.read(miniAppControllerProvider.notifier);
    ref.onDispose(() {
      _saveTimer?.cancel();
      if (_unsaved case final url?) unawaited(apps.rememberPage(appId, url));
    });
    ref.listen<MiniAppNavigation?>(miniAppNavigationProvider, (_, next) {
      if (next == null || next.id != appId || next.seq == _handledSeq) return;
      _consume(next);
      load(next.url);
    });
    return MiniAppBrowserState(initialUrl: initialUrl, address: initialUrl);
  }

  /// Marks [link] handled and clears it, so a page closed to save memory and
  /// opened again later returns to where it was, not to this link.
  void _consume(MiniAppNavigation link) {
    _handledSeq = link.seq;
    Future.microtask(() {
      if (!ref.mounted) return;
      final pending = ref.read(miniAppNavigationProvider.notifier);
      if (pending.state?.seq == link.seq) pending.state = null;
    });
  }

  void attach(InAppWebViewController web) {
    _web = web;
    unawaited(_applyActivity());
    unawaited(_applyBrightness());
  }

  // ---- Light / dark ----

  Brightness? _brightness;
  Brightness? _appliedBrightness;

  /// The look the app shows ([brightness]), which the page's
  /// `prefers-color-scheme` follows, so a page never differs from the app
  /// around it: the OS's look only when the app follows the OS. Windows only:
  /// the web view there takes the OS's look unasked, while macOS's takes the
  /// app window's.
  void setBrightness(Brightness brightness) {
    _brightness = brightness;
    unawaited(_applyBrightness());
  }

  Future<void> _applyBrightness() async {
    final web = _web;
    final brightness = _brightness;
    if (web == null ||
        brightness == null ||
        brightness == _appliedBrightness ||
        defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    _appliedBrightness = brightness;
    await web.callDevToolsProtocolMethod(
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
  }

  // ---- Off screen ----

  bool _active = true;
  bool _keepRunning = false;
  bool _paused = false;
  bool _throttled = false;

  /// Whether the page is on screen ([active]) and, while it is not, whether
  /// it must [keepRunning] (it may show notifications). Off screen it stops
  /// drawing: one that keeps running only hands over a frame a second, any
  /// other is suspended until it is shown again. Windows only: that is where
  /// a hidden web view keeps drawing at full speed.
  void setActivity({required bool active, required bool keepRunning}) {
    _active = active;
    _keepRunning = keepRunning;
    unawaited(_applyActivity());
  }

  Future<void> _applyActivity() async {
    final web = _web;
    if (web == null || defaultTargetPlatform != TargetPlatform.windows) return;
    final pause = !_active && !_keepRunning;
    final throttle = !_active && _keepRunning;
    if (pause != _paused) {
      _paused = pause;
      await (pause ? web.pause() : web.resume());
    }
    if (throttle != _throttled) {
      _throttled = throttle;
      await setWebViewFrameRateLimit(web, throttle ? 1 : 0);
    }
  }

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

  void _rememberLater(String url) {
    _unsaved = url;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () {
      final url = _unsaved;
      _unsaved = null;
      if (url != null) {
        unawaited(
          ref.read(miniAppControllerProvider.notifier).rememberPage(appId, url),
        );
      }
    });
  }

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
      _rememberLater(url.toString());
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

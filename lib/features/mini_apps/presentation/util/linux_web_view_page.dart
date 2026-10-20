import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_all_linux/webview_all_linux.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

import '../../../../core/debug/app_talker.dart';
import 'mini_app_page_capability.dart';
import 'mini_app_page_driver.dart';

/// A mini app's page in WebKitGTK's web view (Linux, webview_all_linux).
///
/// The capabilities' scripts are written for flutter_inappwebview's bridge,
/// `window.flutter_inappwebview.callHandler(name, ...args)` answered with a
/// promise. WebKitGTK only carries messages one way, page to app, so [install]
/// puts the same call in the page on top of a message handler: each call goes
/// out with an id, and the app answers by running a script that settles the
/// promise of that id.
class LinuxMiniAppPage implements MiniAppPageDriver, MiniAppPageBridge {
  LinuxMiniAppPage(this.web);

  final LinuxWebViewController web;

  final _handlers = <String, dynamic Function(List<dynamic> args)>{};

  static const _channel = 'workNexusBridge';

  /// Sets up the bridge; before any other script is added, so it is in place
  /// when theirs run.
  Future<void> install() async {
    await web.addJavaScriptChannel(
      JavaScriptChannelParams(name: _channel, onMessageReceived: _onMessage),
    );
    await web.addUserScript(const WebViewUserScript(source: _bridgeScript));
  }

  /// Adds one of the capabilities' scripts. WebKitGTK only runs a script at
  /// the start of the document, so one meant for its end waits for it.
  Future<void> addScript(UserScript script) => web.addUserScript(
    WebViewUserScript(
      source: script.injectionTime == UserScriptInjectionTime.AT_DOCUMENT_END
          ? _atDocumentEnd(script.source)
          : script.source,
      forMainFrameOnly: script.forMainFrameOnly,
    ),
  );

  static String _atDocumentEnd(String source) =>
      '''
(function () {
  function run() {
$source
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run, { once: true });
  } else {
    run();
  }
})();
''';

  @override
  void addHandler(String name, dynamic Function(List<dynamic> args) handler) =>
      _handlers[name] = handler;

  Future<void> _onMessage(JavaScriptMessage message) async {
    final int id;
    final String name;
    final List<dynamic> args;
    try {
      final call = jsonDecode(message.message) as Map<String, dynamic>;
      id = call['id'] as int;
      name = call['name'] as String;
      args = call['args'] as List<dynamic>;
    } on Object catch (e) {
      appTalker.warning('Mini app bridge: unreadable call ($e)');
      return;
    }
    Object? answer;
    try {
      answer = await _handlers[name]?.call(args);
    } on Object catch (e, st) {
      appTalker.error('Mini app bridge: $name failed', e, st);
    }
    try {
      await web.runJavaScript(
        'window.__workNexusBridgeSettle($id, ${jsonEncode(answer)});',
      );
    } on Object catch (e) {
      // The page moved on meanwhile; its promise went with it.
      appTalker.debug('Mini app bridge: $name answered too late ($e)');
    }
  }

  static const _bridgeScript =
      '''
(function () {
  if (window.flutter_inappwebview) return;
  var pending = new Map();
  var next = 0;
  Object.defineProperty(window, '__workNexusBridgeSettle', {
    value: function (id, value) {
      var settle = pending.get(id);
      if (!settle) return;
      pending.delete(id);
      settle(value);
    },
  });
  window.flutter_inappwebview = {
    callHandler: function (name) {
      var args = Array.prototype.slice.call(arguments, 1);
      return new Promise(function (resolve) {
        var id = ++next;
        pending.set(id, resolve);
        window.webkit.messageHandlers.$_channel.postMessage(
          JSON.stringify({ id: id, name: name, args: args }));
      });
    },
  };
})();
''';

  @override
  Future<Uri?> currentUrl() async {
    final url = await web.currentUrl();
    return url == null ? null : Uri.tryParse(url);
  }

  @override
  void load(String url) =>
      unawaited(web.loadRequest(LoadRequestParams(uri: Uri.parse(url))));

  @override
  void reload() => unawaited(web.reload());

  /// WebKitGTK's reload without the cache is not offered by the plugin.
  @override
  void hardReload() => reload();

  @override
  void stop() => unawaited(web.runJavaScript('window.stop();'));

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

  /// WebKitGTK follows the GTK theme the app window has.
  @override
  Future<void> setColorScheme(Brightness brightness) async {}

  /// A hidden WebKitGTK view stops drawing on its own.
  @override
  Future<void> setSuspended(bool suspended) async {}

  @override
  Future<void> setFrameRateLimit(int framesPerSecond) async {}
}

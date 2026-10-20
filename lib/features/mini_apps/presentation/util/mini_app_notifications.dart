import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/platform/desktop_window_service.dart';
import '../../domain/entities/mini_app_permission.dart';
import '../../domain/usecases/is_mini_app_origin.dart';
import '../providers/mini_app_providers.dart';
import 'ask_mini_app_permission.dart';
import 'mini_app_page_capability.dart';
import 'mini_app_page_token.dart';

/// What a notification's payload starts with, so a tap on it finds its mini
/// app again ([miniAppIdOfNotificationPayload]).
const _payloadPrefix = 'mini:';

String miniAppNotificationPayload(String miniAppId) =>
    '$_payloadPrefix$miniAppId';

/// The mini app a tapped notification belongs to; null for any other.
String? miniAppIdOfNotificationPayload(String payload) =>
    payload.startsWith(_payloadPrefix)
    ? payload.substring(_payloadPrefix.length)
    : null;

/// Lets a page show notifications, as OS notifications. The web view has no
/// notification event of its own on Windows, so a script replaces the page's
/// `Notification` (and `showNotification` called on a service worker
/// registration from the page) with one that reports to the app. A
/// notification raised inside the service worker itself (on a push) is not
/// seen: the script does not run there. The permission it reports is the one
/// the user gave, asked for the first time the page requests it; a page on
/// another site than the app's is always denied.
///
/// The web view's JavaScript bridge is open to every frame (macOS injects it
/// into iframes too), and [MiniAppPageBridge.currentUrl] names the main
/// frame, not the caller. So each call carries a [token] that only the
/// main-frame script knows — a cross-origin iframe cannot read it — and a
/// call without it is ignored.
class MiniAppNotificationCapability implements MiniAppPageCapability {
  MiniAppNotificationCapability({String? token})
    : token = token ?? newMiniAppPageToken();

  /// The secret the script passes first on each call.
  final String token;

  static const _kinds = [MiniAppPermissionKind.notifications];

  @override
  late final UserScript userScript = UserScript(
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    source: _script.replaceAll('__TOKEN__', token),
  );

  /// Whether a handler call came from this capability's own script: its first
  /// argument is the [token].
  bool isOwnCall(List<dynamic> args) => args.isNotEmpty && args.first == token;

  @override
  void attach(MiniAppPageBridge bridge, MiniAppPageContext page) {
    final ref = page.ref;
    final permissions = ref.read(miniAppPermissionControllerProvider.notifier);
    Future<bool> onAppSite() async =>
        const IsMiniAppOrigin()(page.app().url, await bridge.currentUrl());

    bridge.addHandler('miniAppNotificationState', (args) async {
      if (!isOwnCall(args) || !await onAppSite()) return 'denied';
      return switch (await permissions.remembered(page.app().id, _kinds)) {
        MiniAppPermissionDecision.allow => 'granted',
        MiniAppPermissionDecision.block => 'denied',
        null => 'default',
      };
    });

    bridge.addHandler('miniAppNotificationPermission', (args) async {
      if (!isOwnCall(args)) return 'denied';
      final at = await bridge.currentUrl();
      if (!page.context.mounted) return 'denied';
      final answer = await askMiniAppPermission(
        page.context,
        ref,
        page.app(),
        _kinds,
        origin: at,
      );
      return answer == MiniAppPermissionDecision.allow ? 'granted' : 'denied';
    });

    bridge.addHandler('miniAppNotify', (args) async {
      if (args.length < 2 || !isOwnCall(args) || !await onAppSite()) return;
      final app = page.app();
      final allowed = await permissions.remembered(app.id, _kinds);
      if (allowed != MiniAppPermissionDecision.allow) return;
      final title = '${args[1]}';
      final body = args.length > 2 ? '${args[2]}' : '';
      final tag = args.length > 3 ? '${args[3]}' : '';
      // The user is looking at this very page: it needs no pop-up.
      final showing = ref.read(miniAppShownProvider(app.id));
      if (showing && await const DesktopWindowService().isFocused()) return;
      await ref
          .read(miniAppNotifierProvider)
          .show(
            // One per tag, so a page updating a notification replaces it.
            id: Object.hash(app.id, tag.isEmpty ? title : tag) & 0x7fffffff,
            title: title,
            body: body,
            payload: miniAppNotificationPayload(app.id),
          );
    });
  }

  static const _script = r'''
(() => {
  if (window.__wnNotifications) return;
  window.__wnNotifications = true;
  const token = '__TOKEN__';
  const call = (name, ...args) => new Promise((resolve) => {
    const go = () => resolve(window.flutter_inappwebview.callHandler(name, token, ...args));
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      go();
    } else {
      window.addEventListener('flutterInAppWebViewPlatformReady', go, { once: true });
    }
  });
  let permission = 'default';
  call('miniAppNotificationState').then((p) => { permission = p; }).catch(() => {});
  const notify = (title, options) => {
    const o = options || {};
    call('miniAppNotify', String(title), String(o.body || ''), String(o.tag || ''));
  };
  class WNNotification extends EventTarget {
    constructor(title, options) {
      super();
      const o = options || {};
      this.title = String(title);
      this.body = String(o.body || '');
      this.icon = String(o.icon || '');
      this.tag = String(o.tag || '');
      this.data = o.data;
      this.onclick = this.onclose = this.onerror = this.onshow = null;
      notify(title, o);
      setTimeout(() => {
        const e = new Event('show');
        if (this.onshow) this.onshow(e);
        this.dispatchEvent(e);
      });
    }
    close() {}
    static get permission() { return permission; }
    static get maxActions() { return 0; }
    static requestPermission(callback) {
      return call('miniAppNotificationPermission').then((p) => {
        permission = p;
        if (callback) callback(p);
        return p;
      });
    }
  }
  Object.defineProperty(window, 'Notification', {
    value: WNNotification, writable: true, configurable: true,
  });
  if (window.ServiceWorkerRegistration) {
    ServiceWorkerRegistration.prototype.showNotification = function (title, options) {
      notify(title, options);
      return Promise.resolve();
    };
  }
})();
''';
}

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/platform/desktop_window_service.dart';
import '../../domain/entities/mini_app_permission.dart';
import '../../domain/usecases/is_mini_app_origin.dart';
import '../providers/mini_app_providers.dart';
import 'ask_mini_app_permission.dart';
import 'mini_app_page_capability.dart';

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
class MiniAppNotificationCapability implements MiniAppPageCapability {
  MiniAppNotificationCapability();

  static const _kinds = [MiniAppPermissionKind.notifications];

  @override
  final UserScript userScript = UserScript(
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    source: _script,
  );

  @override
  void attach(InAppWebViewController controller, MiniAppPageContext page) {
    final app = page.app;
    final ref = page.ref;
    final permissions = ref.read(miniAppPermissionControllerProvider.notifier);
    // The script runs in the main frame only, so the page's address is the
    // caller's.
    Future<Uri?> origin() => controller.getUrl();
    Future<bool> onAppSite() async =>
        const IsMiniAppOrigin()(app.url, await origin());

    controller.addJavaScriptHandler(
      handlerName: 'miniAppNotificationState',
      callback: (_) async {
        if (!await onAppSite()) return 'denied';
        return switch (await permissions.remembered(app.id, _kinds)) {
          MiniAppPermissionDecision.allow => 'granted',
          MiniAppPermissionDecision.block => 'denied',
          null => 'default',
        };
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'miniAppNotificationPermission',
      callback: (_) async {
        final at = await origin();
        if (!page.context.mounted) return 'denied';
        final answer = await askMiniAppPermission(
          page.context,
          ref,
          app,
          _kinds,
          origin: at,
        );
        return answer == MiniAppPermissionDecision.allow ? 'granted' : 'denied';
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'miniAppNotify',
      callback: (args) async {
        if (args.isEmpty || !await onAppSite()) return;
        final allowed = await permissions.remembered(app.id, _kinds);
        if (allowed != MiniAppPermissionDecision.allow) return;
        final title = '${args[0]}';
        final body = args.length > 1 ? '${args[1]}' : '';
        final tag = args.length > 2 ? '${args[2]}' : '';
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
      },
    );
  }

  static const _script = r'''
(() => {
  if (window.__wnNotifications) return;
  window.__wnNotifications = true;
  const call = (...args) => new Promise((resolve) => {
    const go = () => resolve(window.flutter_inappwebview.callHandler(...args));
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

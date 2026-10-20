import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' show WebUri;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_all_linux/webview_all_linux.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/entities/mini_app_permission.dart';
import '../providers/mini_app_browser_controller.dart';
import '../providers/mini_app_providers.dart';
import '../util/ask_mini_app_permission.dart';
import '../util/linux_web_view_page.dart';
import '../util/mini_app_login_capability.dart';
import '../util/mini_app_notifications.dart';
import '../util/mini_app_page_capability.dart';

/// The web page of a mini app on Linux, in WebKitGTK: what the Windows and
/// macOS web view is elsewhere, with what WebKitGTK offers. A page's own
/// windows (`window.open`, `target=_blank`) load in this page, and the
/// permissions it can ask for are the camera and the microphone.
///
/// The page is a native view laid over the window, so nothing Flutter draws
/// shows on top of it: it is hidden while a dialog or menu, or one of the
/// shell's panels, is over it.
class MiniAppLinuxWebView extends ConsumerStatefulWidget {
  const MiniAppLinuxWebView({super.key, required this.app});

  final MiniApp app;

  @override
  ConsumerState<MiniAppLinuxWebView> createState() =>
      _MiniAppLinuxWebViewState();
}

class _MiniAppLinuxWebViewState extends ConsumerState<MiniAppLinuxWebView> {
  final _web = LinuxWebViewController(
    const LinuxWebViewControllerCreationParams(
      javascriptCanOpenWindowsAutomatically: true,
      developerExtrasEnabled: true,
    ),
  );
  late final _page = LinuxMiniAppPage(_web);
  late final _view = LinuxWebViewWidget(
    LinuxWebViewWidgetCreationParams(controller: _web),
  );
  final _capabilities = <MiniAppPageCapability>[
    MiniAppNotificationCapability(),
    MiniAppLoginCapability(),
  ];

  MiniApp get app => widget.app;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    unawaited(_web.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    final browser = ref.read(miniAppBrowserProvider(app.id).notifier);
    final name = app.name;
    final delegate = LinuxNavigationDelegate(
      const LinuxNavigationDelegateCreationParams(),
    );
    await delegate.setOnPageStarted((url) {
      appTalker.info('Mini app $name: loading $url');
      browser.onLoadStart();
    });
    await delegate.setOnProgress(
      (percent) => browser.onProgress(percent / 100),
    );
    await delegate.setOnUrlChange((change) {
      if (change.url case final url?) unawaited(browser.onVisited(WebUri(url)));
    });
    await delegate.setOnWebResourceError((error) {
      appTalker.error('Mini app $name: ${error.url} → ${error.description}');
      if (error.isForMainFrame ?? true) browser.onError(error.description);
    });
    await _web.setPlatformNavigationDelegate(delegate);
    await _web.setOnPlatformPermissionRequest(
      (request) => unawaited(_answerPermission(request)),
    );
    await _page.install();
    if (!mounted) return;
    final page = MiniAppPageContext(
      context: context,
      ref: ref,
      app: () => currentMiniApp(ref, app),
    );
    for (final capability in _capabilities) {
      if (capability.userScript case final script?) {
        await _page.addScript(script);
      }
      capability.attach(_page, page);
    }
    if (!mounted) return;
    browser.attach(_page);
    _page.load(ref.read(miniAppBrowserProvider(app.id)).initialUrl);
  }

  Future<void> _answerPermission(
    PlatformWebViewPermissionRequest request,
  ) async {
    final kinds = [
      for (final type in request.types)
        if (type == WebViewPermissionResourceType.camera)
          MiniAppPermissionKind.camera
        else if (type == WebViewPermissionResourceType.microphone)
          MiniAppPermissionKind.microphone,
    ];
    final origin = await _page.currentUrl();
    if (!mounted) return request.deny();
    final decision = await askMiniAppPermission(
      context,
      ref,
      currentMiniApp(ref, app),
      kinds,
      origin: origin,
    );
    await (decision == MiniAppPermissionDecision.allow
        ? request.grant()
        : request.deny());
  }

  @override
  Widget build(BuildContext context) {
    final covered =
        !(ModalRoute.isCurrentOf(context) ?? true) ||
        ref.watch(_shellPanelOpenProvider);
    return Offstage(offstage: covered, child: _view.build(context));
  }
}

/// Whether one of the shell's panels — they open over the current view — is
/// open.
final _shellPanelOpenProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(openTicketIdProvider) != null ||
      ref.watch(notificationsPanelOpenProvider) ||
      ref.watch(quickSettingsOpenProvider) ||
      ref.watch(talkerDebugOpenProvider),
);

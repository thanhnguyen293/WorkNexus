import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../domain/entities/mini_app.dart';
import '../providers/mini_app_browser_controller.dart';
import '../providers/mini_app_providers.dart';
import '../util/ask_mini_app_permission.dart';
import '../util/mini_app_notifications.dart';
import '../util/mini_app_page_capability.dart';
import 'mini_app_popup.dart';

/// The web page of a mini app, with the app's answers to what the page asks
/// for: permissions (asked of the user once, then remembered), the
/// [capabilities] the app lends it (notifications), and its own windows
/// (opened over the app). What the page does is reported to the app's
/// [MiniAppBrowserController].
class MiniAppWebView extends ConsumerWidget {
  MiniAppWebView({
    super.key,
    required this.app,
    List<MiniAppPageCapability>? capabilities,
  }) : capabilities = capabilities ?? [MiniAppNotificationCapability()];

  final MiniApp app;
  final List<MiniAppPageCapability> capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = app.name;
    final browser = ref.read(miniAppBrowserProvider(app.id).notifier);
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(ref.read(miniAppBrowserProvider(app.id)).initialUrl),
      ),
      initialUserScripts: UnmodifiableListView([
        for (final capability in capabilities) ?capability.userScript,
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
        isInspectable: kDebugMode,
      ),
      onWebViewCreated: (controller) {
        final page = MiniAppPageContext(
          context: context,
          ref: ref,
          app: () => currentMiniApp(ref, app),
        );
        for (final capability in capabilities) {
          capability.attach(controller, page);
        }
        browser.attach(controller);
      },
      onPermissionRequest: (_, request) => answerMiniAppPermission(
        context,
        ref,
        currentMiniApp(ref, app),
        request,
      ),
      onLoadStart: (_, url) {
        appTalker.info('Mini app $name: loading $url');
        browser.onLoadStart();
      },
      onUpdateVisitedHistory: (_, url, _) {
        if (url != null) unawaited(browser.onVisited(url));
      },
      onProgressChanged: (_, percent) => browser.onProgress(percent / 100),
      onReceivedError: (_, request, error) {
        appTalker.error(
          'Mini app $name: ${request.url} → ${error.description}',
        );
        if (request.isForMainFrame ?? true) browser.onError(error.description);
      },
      onReceivedHttpError: (_, request, response) => appTalker.warning(
        'Mini app $name: ${request.url} → HTTP ${response.statusCode}',
      ),
      onConsoleMessage: (_, message) =>
          appTalker.debug('Mini app $name console: ${message.message}'),
      // A page's own window (a sign-in pop-up, target=_blank) opens over the
      // mini app; the browser only opens from its button.
      onCreateWindow: (_, action) async {
        if (!context.mounted) return false;
        unawaited(MiniAppPopup.show(context, action.windowId));
        return true;
      },
    );
  }
}

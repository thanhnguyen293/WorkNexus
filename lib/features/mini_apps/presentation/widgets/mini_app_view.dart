import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/navigation/mini_app_links.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/usecases/normalize_mini_app_url.dart';
import '../providers/mini_app_providers.dart';
import 'mini_app_popup.dart';
import 'mini_app_toolbar.dart';

/// One mini app: a browser-style bar over the web page. Windows and macOS
/// embed the page; elsewhere (Linux has no web view backend) the page opens in
/// the system browser instead.
class MiniAppView extends ConsumerStatefulWidget {
  const MiniAppView({super.key, required this.app});

  final MiniApp app;

  static bool get embedded =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  ConsumerState<MiniAppView> createState() => _MiniAppViewState();
}

class _MiniAppViewState extends ConsumerState<MiniAppView> {
  InAppWebViewController? _web;
  double _progress = 1;
  bool _canGoBack = false;
  bool _canGoForward = false;

  /// Why the page could not load (shown in place of it); null while fine.
  String? _loadError;

  late final _address = TextEditingController(text: widget.app.url);
  final _addressFocus = FocusNode();

  /// The address the page first opens on: the link that opened this app, if
  /// it was opened by one, else the address it was added with.
  late String _initialUrl;
  int _handledSeq = 0;

  @override
  void initState() {
    super.initState();
    _initialUrl = widget.app.lastUrl ?? widget.app.url;
    final pending = ref.read(miniAppNavigationProvider);
    if (pending != null && pending.id == widget.app.id) {
      _initialUrl = pending.url;
      _handledSeq = pending.seq;
    }
    _address.text = _initialUrl;
    ref.listenManual<MiniAppNavigation?>(miniAppNavigationProvider, (_, next) {
      if (next == null || next.id != widget.app.id) return;
      if (next.seq == _handledSeq) return;
      _handledSeq = next.seq;
      _web?.loadUrl(urlRequest: URLRequest(url: WebUri(next.url)));
    });
  }

  @override
  void dispose() {
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _openExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  void _focusAddress() {
    _addressFocus.requestFocus();
    _address.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _address.text.length,
    );
  }

  /// The browser's usual keys, while this mini app has focus. Ctrl and Cmd are
  /// interchangeable so the same keys work on Windows and macOS.
  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    if (!MiniAppView.embedded) return const {};
    void reload() => _web?.reload();
    // Reload that skips the cache, through the DevTools protocol.
    void hardReload() => _web?.callDevToolsProtocolMethod(
      methodName: 'Page.reload',
      parameters: {'ignoreCache': true},
    );
    void back() => _canGoBack ? _web?.goBack() : null;
    void forward() => _canGoForward ? _web?.goForward() : null;
    void devTools() => _web?.openDevTools();
    return {
      for (final ctrl in const [true, false]) ...{
        SingleActivator(LogicalKeyboardKey.keyR, control: ctrl, meta: !ctrl):
            reload,
        SingleActivator(LogicalKeyboardKey.keyL, control: ctrl, meta: !ctrl):
            _focusAddress,
        SingleActivator(
          LogicalKeyboardKey.keyI,
          control: ctrl,
          meta: !ctrl,
          shift: true,
        ): devTools,
      },
      const SingleActivator(LogicalKeyboardKey.f5): reload,
      const SingleActivator(LogicalKeyboardKey.f5, control: true): hardReload,
      const SingleActivator(LogicalKeyboardKey.f6): _focusAddress,
      const SingleActivator(LogicalKeyboardKey.f12): devTools,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): back,
      const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): forward,
    };
  }

  /// Goes to what was typed in the address bar.
  void _go(String text) {
    final uri = const NormalizeMiniAppUrl()(text);
    if (uri == null) return;
    _web?.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
  }

  /// Keeps the page the user is on, to reopen it next time. Only web pages.
  void _rememberPage(WebUri url) {
    if (url.scheme != 'http' && url.scheme != 'https') return;
    ref
        .read(miniAppControllerProvider.notifier)
        .rememberPage(widget.app.id, url.toString());
  }

  Future<void> _refreshHistory() async {
    final web = _web;
    if (web == null) return;
    final back = await web.canGoBack();
    final forward = await web.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final name = widget.app.name;
    final embedded = MiniAppView.embedded;
    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Column(
        children: [
          MiniAppToolbar(
            address: _address,
            addressFocus: _addressFocus,
            showNavigation: embedded,
            loading: _progress < 1,
            onBack: _canGoBack ? () => _web?.goBack() : null,
            onForward: _canGoForward ? () => _web?.goForward() : null,
            onReload: () => _web?.reload(),
            onStop: () => _web?.stopLoading(),
            onDevTools: embedded ? () => _web?.openDevTools() : null,
            onSubmitted: embedded
                ? _go
                : (text) {
                    final uri = const NormalizeMiniAppUrl()(text);
                    if (uri != null) _openExternal(uri);
                  },
            onOpenExternal: () => _openExternal(
              Uri.tryParse(_address.text) ?? Uri.parse(widget.app.url),
            ),
          ),
          if (_progress < 1)
            LinearProgressIndicator(value: _progress, minHeight: s.xxs),
          Expanded(
            child: embedded
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      InAppWebView(
                        initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                        initialSettings: InAppWebViewSettings(
                          javaScriptCanOpenWindowsAutomatically: true,
                          supportMultipleWindows: true,
                          isInspectable: kDebugMode,
                        ),
                        onWebViewCreated: (controller) => _web = controller,
                        onLoadStart: (_, url) {
                          appTalker.info('Mini app $name: loading $url');
                          if (_loadError != null) {
                            setState(() => _loadError = null);
                          }
                        },
                        onUpdateVisitedHistory: (_, url, _) {
                          if (url != null) {
                            _address.text = url.toString();
                            _rememberPage(url);
                          }
                          _refreshHistory();
                        },
                        onProgressChanged: (_, percent) =>
                            setState(() => _progress = percent / 100),
                        onReceivedError: (_, request, error) {
                          appTalker.error(
                            'Mini app $name: ${request.url} → ${error.description}',
                          );
                          if (request.isForMainFrame ?? true) {
                            setState(() => _loadError = error.description);
                          }
                        },
                        onReceivedHttpError: (_, request, response) =>
                            appTalker.warning(
                              'Mini app $name: ${request.url} → HTTP '
                              '${response.statusCode}',
                            ),
                        onConsoleMessage: (_, message) => appTalker.debug(
                          'Mini app $name console: ${message.message}',
                        ),
                        // A page's own window (a sign-in pop-up, target=_blank)
                        // opens over the mini app; the browser only opens from
                        // its button.
                        onCreateWindow: (_, action) async {
                          if (!mounted) return false;
                          unawaited(
                            MiniAppPopup.show(context, action.windowId),
                          );
                          return true;
                        },
                      ),
                      if (_loadError case final error?)
                        ColoredBox(
                          color: c.background,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: s.md,
                              children: [
                                Text(l.miniAppLoadFailed),
                                Text(
                                  error,
                                  style: context.typography.caption.copyWith(
                                    color: c.textTertiary,
                                  ),
                                ),
                                AppButton.filled(
                                  onPressed: () => _web?.reload(),
                                  child: Text(l.miniAppRetry),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: s.xl,
                      children: [
                        Text(l.miniAppUnsupported),
                        AppButton.filled(
                          onPressed: () =>
                              _openExternal(Uri.parse(widget.app.url)),
                          child: Text(l.miniAppOpenInBrowser),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

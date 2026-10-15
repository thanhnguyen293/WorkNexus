import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/usecases/normalize_mini_app_url.dart';
import '../providers/mini_app_browser_controller.dart';
import '../util/mini_app_shortcuts.dart';
import 'mini_app_load_error.dart';
import 'mini_app_toolbar.dart';
import 'mini_app_unsupported.dart';
import 'mini_app_web_view.dart';

/// One mini app: a browser-style bar over the web page. Windows and macOS
/// embed the page; elsewhere (Linux has no web view backend) the page opens in
/// the system browser instead. What the page is doing lives in the app's
/// [MiniAppBrowserController]; this only draws it and keeps the address field.
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
  final _address = TextEditingController();
  final _addressFocus = FocusNode();

  /// Kept while the app is unchanged: the same widget instance is not rebuilt,
  /// so the page is left alone on every progress tick of the bar above it.
  late MiniAppWebView _webView = MiniAppWebView(app: widget.app);

  @override
  void initState() {
    super.initState();
    _address.text = ref.read(miniAppBrowserProvider(widget.app.id)).address;
    // The field follows the page as it moves.
    ref.listenManual(
      miniAppBrowserProvider(widget.app.id).select((s) => s.address),
      (_, address) => _address.text = address,
    );
  }

  @override
  void didUpdateWidget(MiniAppView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app != widget.app) {
      _webView = MiniAppWebView(app: widget.app);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  MiniAppBrowserController get _browser =>
      ref.read(miniAppBrowserProvider(widget.app.id).notifier);

  Future<void> _openExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Goes to what was typed in the address bar: in the page, or — where there
  /// is none — the browser.
  void _go(String text) {
    final uri = const NormalizeMiniAppUrl()(text);
    if (uri == null) return;
    if (MiniAppView.embedded) {
      _browser.load(uri.toString());
    } else {
      _openExternal(uri);
    }
  }

  void _focusAddress() {
    _addressFocus.requestFocus();
    _address.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _address.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(miniAppBrowserProvider(widget.app.id));
    final embedded = MiniAppView.embedded;
    return CallbackShortcuts(
      bindings: embedded
          ? miniAppShortcuts(
              reload: _browser.reload,
              hardReload: _browser.hardReload,
              back: _browser.goBack,
              forward: _browser.goForward,
              focusAddress: _focusAddress,
              devTools: _browser.openDevTools,
            )
          : const {},
      child: Column(
        children: [
          MiniAppToolbar(
            address: _address,
            addressFocus: _addressFocus,
            showNavigation: embedded,
            loading: state.loading,
            onBack: state.canGoBack ? _browser.goBack : null,
            onForward: state.canGoForward ? _browser.goForward : null,
            onReload: _browser.reload,
            onStop: _browser.stop,
            onDevTools: embedded ? _browser.openDevTools : null,
            onSubmitted: _go,
            onOpenExternal: () => _openExternal(
              Uri.tryParse(_address.text) ?? Uri.parse(widget.app.url),
            ),
          ),
          if (state.loading)
            LinearProgressIndicator(
              value: state.progress,
              minHeight: context.spacing.xxs,
            ),
          Expanded(
            child: embedded
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      _webView,
                      if (state.loadError case final error?)
                        MiniAppLoadError(
                          message: error,
                          onRetry: _browser.reload,
                        ),
                    ],
                  )
                : MiniAppUnsupported(
                    onOpenExternal: () =>
                        _openExternal(Uri.parse(widget.app.url)),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import 'mini_app_popup_header.dart';

/// The window a page asked for (`window.open`, a `target="_blank"` link, a
/// sign-in pop-up) shown over the mini app, inside the app. It is the page's
/// own window, so the page can talk back to its opener and close it — what a
/// pop-up sign-in needs to finish. Its bar goes back and forward through the
/// pages it has been to and opens the current page in the browser.
class MiniAppPopup extends StatefulWidget {
  const MiniAppPopup({super.key, required this.windowId});

  final int windowId;

  /// Shows the pop-up for [windowId]; resolves when it closes.
  static Future<void> show(BuildContext context, int windowId) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MiniAppPopup(windowId: windowId),
      );

  /// Whether [url] is a page the browser can be given: a web address, not
  /// the blank page a pop-up starts on.
  static bool isWebAddress(Uri? url) =>
      url != null && (url.scheme == 'http' || url.scheme == 'https');

  @override
  State<MiniAppPopup> createState() => _MiniAppPopupState();
}

class _MiniAppPopupState extends State<MiniAppPopup> {
  InAppWebViewController? _web;
  String _title = '';
  Uri? _url;
  bool _canGoBack = false;
  bool _canGoForward = false;

  /// The page moved: where it is, and whether it can go back or forward.
  Future<void> _onVisited(WebUri? url) async {
    final web = _web;
    if (web == null) return;
    final back = await web.canGoBack();
    final forward = await web.canGoForward();
    if (!mounted) return;
    setState(() {
      _url = url ?? _url;
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final size = MediaQuery.sizeOf(context);
    final url = _url;
    return Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.all(s.xl5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width.clamp(0, 520),
        height: size.height.clamp(0, 720),
        child: Column(
          children: [
            MiniAppPopupHeader(
              title: _title,
              onClose: () => Navigator.of(context).pop(),
              onBack: _canGoBack ? () => _web?.goBack() : null,
              onForward: _canGoForward ? () => _web?.goForward() : null,
              onOpenExternal: MiniAppPopup.isWebAddress(url)
                  ? () => unawaited(openExternally(url.toString()))
                  : null,
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: InAppWebView(
                windowId: widget.windowId,
                initialSettings: InAppWebViewSettings(
                  javaScriptCanOpenWindowsAutomatically: true,
                  isInspectable: kDebugMode,
                ),
                onWebViewCreated: (controller) => _web = controller,
                onTitleChanged: (_, title) =>
                    setState(() => _title = title ?? ''),
                onUpdateVisitedHistory: (_, url, _) =>
                    unawaited(_onVisited(url)),
                // The page closes its own window when it is done (sign-in).
                onCloseWindow: (_) {
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

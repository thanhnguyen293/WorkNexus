import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mini_app.dart';

/// Where a page's request is being answered: the app it belongs to and the
/// view's own context and [ref] (for dialogs and providers).
class MiniAppPageContext {
  const MiniAppPageContext({
    required this.context,
    required this.ref,
    required this.app,
  });

  final BuildContext context;
  final WidgetRef ref;
  final MiniApp app;
}

/// Something the app lets a mini app's page do through the app itself — show a
/// notification, later save a download. Each is its own class; the web view
/// only knows this interface, so a new capability is added without touching
/// it.
abstract interface class MiniAppPageCapability {
  /// A script run in every page before its own, to take over the web API the
  /// capability stands behind; null when none is needed.
  UserScript? get userScript;

  /// Answers the calls the capability's script (or the web view) makes.
  void attach(InAppWebViewController controller, MiniAppPageContext page);
}

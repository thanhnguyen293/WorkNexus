import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mini_app.dart';

/// Where a page's request is being answered: the app it belongs to and the
/// view's own context and [ref] (for dialogs and providers). [app] is read at
/// each call, so an app edited after its page opened (a new address) is
/// judged by what it is now.
class MiniAppPageContext {
  const MiniAppPageContext({
    required this.context,
    required this.ref,
    required this.app,
  });

  final BuildContext context;
  final WidgetRef ref;
  final MiniApp Function() app;
}

/// The way from a page's scripts to the app, whichever web view shows the
/// page: a script calls `window.flutter_inappwebview.callHandler(name, ...)`
/// and gets back what the handler of that [name] answers (or completes
/// with), as JSON.
abstract interface class MiniAppPageBridge {
  void addHandler(String name, dynamic Function(List<dynamic> args) handler);

  /// The address of the page's main frame.
  Future<Uri?> currentUrl();
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
  void attach(MiniAppPageBridge bridge, MiniAppPageContext page);
}

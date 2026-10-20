import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'mini_app_page_capability.dart';

/// Lets a Flutter web page keep the focus of its text fields while the user
/// clicks inside it. The Windows web view loses the focus of its window for a
/// moment around each click (the page's `document.hasFocus()` turns false and
/// true again within milliseconds). A Flutter web app takes that for the app
/// being left, drops the focus of the text field and closes what hangs on it,
/// so the option of an autocomplete list (or any menu opened from a field) is
/// gone before the click lets go and cannot be picked.
///
/// The script hides that moment from the page: while the document has no
/// focus, `blur` and `focusout` events, and the window's own `blur` / `focus`,
/// go no further than the script. It acts only on a Flutter web page (one with
/// a `flutter-view` element), and the page keeps every event once the document
/// has its focus back.
class MiniAppFlutterWebFocusCapability implements MiniAppPageCapability {
  MiniAppFlutterWebFocusCapability();

  @override
  late final UserScript userScript = UserScript(
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    source: script,
  );

  @override
  void attach(MiniAppPageBridge bridge, MiniAppPageContext page) {}

  /// The script, also run by tests and tools that want to see it work.
  static const script = r'''
(function () {
  var flutter = false;
  function isFlutter() {
    return flutter || (flutter = !!document.querySelector('flutter-view, flt-glass-pane'));
  }
  function atWindow(e) {
    return e.target === window || e.target === document;
  }
  // The element (or the window) lost focus because the web view did, not
  // because the user went elsewhere in the page.
  function guard(e) {
    if (isFlutter() && (atWindow(e) || !document.hasFocus())) {
      e.stopImmediatePropagation();
    }
  }
  window.addEventListener('blur', guard, true);
  window.addEventListener('focusout', guard, true);
  window.addEventListener('focus', function (e) {
    if (isFlutter() && atWindow(e)) e.stopImmediatePropagation();
  }, true);
})();
''';
}

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/di/providers.dart';
import 'mini_app_page_capability.dart';
import 'mini_app_page_token.dart';

/// Signs in a mini app that shows a ZenTao server the app has an account on,
/// with that account's saved login — the web view remembers no passwords of
/// its own. It fills the form when it is empty, and only for the server's own
/// page: the script asks the app for the login, and the app answers when the
/// main frame is that server. A call without the page's [token] (an iframe's)
/// is ignored.
///
/// The form is submitted once per page of the app that is open (this object
/// lives as long as that view): a wrong password is not tried again and again
/// (ZenTao may lock the account), and after signing out the form is filled but
/// left to the user, so signing out and switching account still work.
class MiniAppLoginCapability implements MiniAppPageCapability {
  MiniAppLoginCapability({String? token})
    : token = token ?? newMiniAppPageToken();

  final String token;

  bool _submitted = false;

  @override
  late final UserScript userScript = UserScript(
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
    source: _script.replaceAll('__TOKEN__', token),
    // The main frame only (the default): a login inside an iframe is not ours
    // to fill.
  );

  @override
  void attach(InAppWebViewController controller, MiniAppPageContext page) {
    controller.addJavaScriptHandler(
      handlerName: 'miniAppLogin',
      callback: (args) async {
        if (args.isEmpty || args.first != token) return null;
        final login = await page.ref.read(savedWebLoginProvider)(
          await controller.getUrl(),
        );
        if (login == null) return null;
        final submit = !_submitted;
        _submitted = true;
        return {
          'account': login.account,
          'password': login.password,
          'submit': submit,
        };
      },
    );
  }

  /// Watches for a visible, empty password field (the form may be drawn after
  /// the page loads), asks once for the login, and puts it in that field and
  /// the text field before it — as typed, so a framework's form sees it —
  /// then signs in when the app says to: the form's submit button, else the
  /// form itself, else Enter in the password field. Asks again only after the
  /// field has gone and come back.
  static const _script = r'''
(function () {
  var asked = false;
  function visible(el) {
    return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
  }
  function set(el, value) {
    var setter = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype, 'value').set;
    setter.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  function userField(password) {
    var root = password.form || document;
    var named = root.querySelector('input[name=account], #account');
    if (named && visible(named)) return named;
    var fields = [].slice.call(root.querySelectorAll(
      'input:not([type]), input[type=text], input[type=email], input[type=tel]'
    )).filter(visible);
    var before = fields.filter(function (f) {
      return f.compareDocumentPosition(password) &
        Node.DOCUMENT_POSITION_FOLLOWING;
    });
    return before.length ? before[before.length - 1] : null;
  }
  function submit(password) {
    var root = password.form || document;
    var button = [].slice.call(root.querySelectorAll(
      'button[type=submit], input[type=submit]')).filter(visible)[0];
    if (button) { button.click(); return; }
    if (password.form && password.form.requestSubmit) {
      password.form.requestSubmit();
      return;
    }
    ['keydown', 'keypress', 'keyup'].forEach(function (type) {
      password.dispatchEvent(new KeyboardEvent(type, {
        key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
    });
  }
  function check() {
    var password = [].slice.call(
      document.querySelectorAll('input[type=password]')).filter(visible)[0];
    if (!password) { asked = false; return; }
    if (asked || password.value) return;
    asked = true;
    window.flutter_inappwebview.callHandler('miniAppLogin', '__TOKEN__')
      .then(function (login) {
        if (!login || password.value) return;
        var user = userField(password);
        if (user && !user.value) set(user, login.account);
        set(password, login.password);
        if (login.submit) setTimeout(function () { submit(password); }, 150);
      });
  }
  new MutationObserver(check).observe(
    document.documentElement, { childList: true, subtree: true });
  check();
})();
''';
}

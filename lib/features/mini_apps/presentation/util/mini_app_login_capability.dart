import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/result.dart';
import '../providers/mini_app_providers.dart';
import 'mini_app_page_capability.dart';
import 'mini_app_page_token.dart';

/// Signs in a mini app that shows a ZenTao server the app has an account on,
/// with that account's saved login — the web view remembers no passwords of
/// its own. It fills ZenTao's login form when it is empty, and only on that
/// server's login page: the script asks the app for the login, and the app
/// answers when the main frame is that page. A call without the page's
/// [token] (an iframe's) is ignored; the login page embeds no other site, so
/// a token another page may have seen earlier finds no frame to use it from.
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
        final found = await page.ref.read(findSavedWebLoginProvider)(
          await controller.getUrl(),
        );
        if (found case Err(:final failure)) {
          appTalker.warning('Mini app login: ${failure.message}');
        }
        final login = found.valueOrNull;
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

  /// Watches for ZenTao's login form — a visible, empty `password` field with
  /// the `account` field beside it; the form may be drawn after the page
  /// loads — asks once for the login, and puts it in those two fields as
  /// typed, so a framework's form sees it. Any other password field (one
  /// confirming a change, say) is left alone. Then signs in when the app says
  /// to: the form's submit button, else the form itself, else Enter in the
  /// password field. Asks again only after the form has gone and come back.
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
  function loginForm() {
    var passwords = [].slice.call(document.querySelectorAll(
      'input[type=password][name=password]')).filter(visible);
    for (var i = 0; i < passwords.length; i++) {
      var root = passwords[i].form || document;
      var account = root.querySelector('input[name=account], #account');
      if (account && visible(account)) {
        return { account: account, password: passwords[i] };
      }
    }
    return null;
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
    var form = loginForm();
    if (!form) { asked = false; return; }
    if (asked || form.password.value) return;
    asked = true;
    window.flutter_inappwebview.callHandler('miniAppLogin', '__TOKEN__')
      .then(function (login) {
        if (!login || form.password.value) return;
        if (!form.account.value) set(form.account, login.account);
        set(form.password, login.password);
        if (login.submit) {
          setTimeout(function () { submit(form.password); }, 150);
        }
      });
  }
  new MutationObserver(check).observe(
    document.documentElement, { childList: true, subtree: true });
  check();
})();
''';
}

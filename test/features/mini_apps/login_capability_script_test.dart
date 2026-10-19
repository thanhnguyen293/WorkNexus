import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/mini_app_login_capability.dart';

void main() {
  final script = MiniAppLoginCapability(token: 'secret-token').userScript;

  test('is in every page, at the end of the document, with its token', () {
    expect(script.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_END);
    expect(script.source, contains('secret-token'));
    expect(script.source, isNot(contains('__TOKEN__')));
  });

  test('looks only on ZenTao\'s login page, in either URL style', () {
    // The script is in the pages of every mini app, so it first checks the
    // address: user-login[-referer].html, or index.php?m=user&f=login.
    expect(script.source, contains('onLoginPage()'));
    expect(script.source, contains("indexOf('user-login') === 0"));
    expect(script.source, contains("q.get('m') === 'user'"));
    expect(script.source, contains("q.get('f') === 'login'"));
  });

  test('looks once per burst of changes, not once per change', () {
    expect(script.source, contains('MutationObserver(schedule)'));
    expect(script.source, contains('if (pending) return;'));
    expect(script.source, contains('}, 50);'));
  });
}

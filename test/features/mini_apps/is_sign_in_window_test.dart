import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/is_sign_in_window.dart';

void main() {
  const isSignIn = IsSignInWindow();
  bool of(String url, {double? width, double? height}) =>
      isSignIn(OpenedWindow(url: url, width: width, height: height));

  group('a window the page sized is a pop-up, so a sign-in', () {
    test('with a width and a height', () {
      expect(of('https://example.com/x', width: 500, height: 600), isTrue);
    });

    test('but not with only one of them, or with none (0 is none)', () {
      expect(of('https://example.com/x', width: 500), isFalse);
      expect(of('https://example.com/x', width: 0, height: 0), isFalse);
      expect(of('https://example.com/x'), isFalse);
    });
  });

  group('the address says it', () {
    test('the usual sign-in addresses', () {
      for (final url in [
        'https://github.com/login/oauth/authorize?scope=x',
        'https://accounts.google.com/o/oauth2/v2/auth',
        'https://login.microsoftonline.com/common/oauth2/authorize',
        'https://example.auth0.com/authorize',
        'https://example.com/sso/start',
        'https://example.com/saml/login',
        'https://example.com/sign-in',
        'https://example.com/log_in',
        'https://zentao.example.com/zentao/user-login-Lw==.html',
        'https://app.example.com/start?client_id=abc',
        'https://app.example.com/cb?redirect_uri=https%3A%2F%2Fx',
        'https://auth.example.com/',
      ]) {
        expect(of(url), isTrue, reason: url);
      }
    });

    test('an ordinary link is not one', () {
      for (final url in [
        'https://www.figma.com/design/abc?node-id=1',
        'https://miro.com/app/board/uXjVabc=/',
        'https://github.com/dyno/worknexus/pull/66',
        'https://example.com/authors/jane',
        'https://example.com/blog/how-to-author',
        'https://trello.com/c/ZYZ5x2jD/88-thay-doi',
        'https://example.com/',
        'https://login.com/',
      ]) {
        expect(of(url), isFalse, reason: url);
      }
    });

    test('a blank or broken address is left to the pop-up', () {
      expect(of('about:blank'), isFalse);
      expect(of(''), isFalse);
      expect(of('::not a url::'), isFalse);
    });
  });
}

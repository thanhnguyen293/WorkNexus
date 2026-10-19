import '../../../../core/usecase/usecase.dart';

/// A window a page opens, as far as the app can tell: where it goes and how
/// big the page asked it to be.
class OpenedWindow {
  const OpenedWindow({required this.url, this.width, this.height});

  final String url;

  /// The size the page gave it (`window.open(url, name, 'width=…,height=…')`);
  /// null or 0 when it gave none, as a `target="_blank"` link does.
  final double? width;
  final double? height;
}

/// Whether a window a page opens is a sign-in: one the page waits on for an
/// answer ("Sign in with Google", a company login), which has to stay a window
/// of its own so it can hand the answer back, and not be carried off to
/// another mini app or the browser.
///
/// It is one when the page gave it a size (a pop-up is asked for that way, a
/// plain link is not), or when its address shows it: a login word in its path
/// (`oauth`, `authorize`, `login`, `signin`, `sso`…), a host that is an
/// identity provider's (`accounts.`, `login.`, `auth.`, `sso.`…), or the
/// parameters of an OAuth request (`client_id`, `redirect_uri`…).
class IsSignInWindow extends UseCase<bool, OpenedWindow> {
  const IsSignInWindow();

  static const _pathWords = {
    'oauth',
    'oauth2',
    'authorize',
    'authorise',
    'authorization',
    'authenticate',
    'auth',
    'login',
    'signin',
    'sso',
    'saml',
    'saml2',
    'openid',
  };

  static const _hostLabels = {
    'accounts',
    'login',
    'signin',
    'auth',
    'sso',
    'idp',
    'oauth',
    'identity',
  };

  static const _queryKeys = {
    'client_id',
    'redirect_uri',
    'response_type',
    'code_challenge',
    'oauth_token',
  };

  @override
  bool call(OpenedWindow window) {
    final width = window.width ?? 0;
    final height = window.height ?? 0;
    if (width > 0 && height > 0) return true;

    final uri = Uri.tryParse(window.url.trim());
    if (uri == null) return false;
    if (uri.queryParameters.keys.any(_queryKeys.contains)) return true;
    final labels = uri.host.toLowerCase().split('.');
    if (labels.length > 2 && _hostLabels.contains(labels.first)) return true;
    // `sign-in`, `log_in` and `user-login.html` all say it in their words.
    final words = uri.path
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty);
    return words.any(_pathWords.contains) ||
        _joined(words).any(_pathWords.contains);
  }

  /// Neighbouring words run together, so `sign-in` and `log-in` read as
  /// `signin` and `login`.
  static Iterable<String> _joined(Iterable<String> words) sync* {
    final list = words.toList();
    for (var i = 0; i + 1 < list.length; i++) {
      yield '${list[i]}${list[i + 1]}';
    }
  }
}

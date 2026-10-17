import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';

/// The sign-in a saved ZenTao account holds, for the page of its own server.
class SavedWebLogin {
  const SavedWebLogin({required this.account, required this.password});

  final String account;
  final String password;
}

/// The saved sign-in for [page], when [page] is the login page of a ZenTao
/// account the app holds a password for: the account's server (same scheme,
/// host and port, so a lookalike or another port gets nothing) and a stored
/// password. `Ok(null)` otherwise. What a mini app's login form is filled with.
///
/// Only the login page itself: any other page of the server (one asking to
/// confirm the password before a change, say) is not handed the password.
class FindSavedWebLogin extends UseCase<Future<Result<SavedWebLogin?>>, Uri?> {
  const FindSavedWebLogin(this._accounts, this._secret);

  final Iterable<Account> Function() _accounts;

  /// The secret kept under a credentials ref, or null.
  final Future<String?> Function(String ref) _secret;

  @override
  Future<Result<SavedWebLogin?>> call(Uri? page) async {
    if (page == null || page.host.isEmpty || !_isLoginPage(page)) {
      return const Ok(null);
    }
    for (final account in _accounts()) {
      final ref = account.credentialsRef;
      final server = Uri.tryParse(account.baseUrl ?? '');
      if (account.providerType != ProviderType.zentao ||
          ref == null ||
          server == null ||
          server.host.isEmpty ||
          server.scheme.toLowerCase() != page.scheme.toLowerCase() ||
          server.host.toLowerCase() != page.host.toLowerCase() ||
          _port(server) != _port(page)) {
        continue;
      }
      final String? password;
      try {
        password = await _secret(ref);
      } on Object catch (error) {
        return Err(StorageFailure('Saved password unreadable', cause: error));
      }
      if (password == null || password.isEmpty) continue;
      return Ok(SavedWebLogin(account: account.handle, password: password));
    }
    return const Ok(null);
  }

  /// ZenTao's login page, in either URL style: `user-login[-<referer>].html`
  /// or `index.php?m=user&f=login`.
  static bool _isLoginPage(Uri page) {
    final last = page.pathSegments.isEmpty ? '' : page.pathSegments.last;
    if (last.startsWith('user-login')) return true;
    final q = page.queryParameters;
    return q['m'] == 'user' && q['f'] == 'login';
  }

  static int _port(Uri uri) =>
      uri.hasPort ? uri.port : (uri.scheme.toLowerCase() == 'https' ? 443 : 80);
}

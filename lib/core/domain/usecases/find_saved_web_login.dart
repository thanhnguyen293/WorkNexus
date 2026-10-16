import '../entities/account.dart';
import '../value_objects/provider_type.dart';

/// The sign-in a saved ZenTao account holds, for the page of its own server.
class SavedWebLogin {
  const SavedWebLogin({required this.account, required this.password});

  final String account;
  final String password;
}

/// The saved sign-in for [page], when [page] is the web of a ZenTao account the
/// app holds a password for: the account's server (same scheme, host and port,
/// so a lookalike or another port gets nothing) and a stored password. Null
/// otherwise. What a mini app's login page is filled with.
class FindSavedWebLogin {
  const FindSavedWebLogin(this._accounts, this._secret);

  final Iterable<Account> Function() _accounts;

  /// The secret kept under a credentials ref, or null.
  final Future<String?> Function(String ref) _secret;

  Future<SavedWebLogin?> call(Uri? page) async {
    if (page == null || page.host.isEmpty) return null;
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
      final password = await _secret(ref);
      if (password == null || password.isEmpty) continue;
      return SavedWebLogin(account: account.handle, password: password);
    }
    return null;
  }

  static int _port(Uri uri) =>
      uri.hasPort ? uri.port : (uri.scheme.toLowerCase() == 'https' ? 443 : 80);
}

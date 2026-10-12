import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/credential_store.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/xxd/xxd_server_info.dart';

/// Builds xxd login credentials for a WorkNexus ZenTao account: the account
/// name (from the stored ZenTao profile, else the typed handle),
/// the password from the OS keychain, the chat server address (overridable,
/// else derived from the ZenTao URL) and the pinned certificate.
class ChatCredentialsResolver {
  ChatCredentialsResolver(this._local, this._store);

  final ChatLocalDatasource _local;
  final CredentialStore _store;

  Future<Result<XxdCredentials>> resolve(String accountId) async {
    try {
      final account = await _local.account(accountId);
      if (account == null || account.providerType != ProviderType.zentao.name) {
        return const Err(NotFoundFailure('Not a ZenTao account'));
      }
      final chat = await _local.chatAccount(accountId);
      final server = chat?.serverUrl != null
          ? Uri.tryParse(chat!.serverUrl!)
          : xxdServerFor(account.baseUrl);
      if (server == null) {
        return const Err(NotFoundFailure('No chat server address'));
      }
      final ref = account.credentialsRef;
      final password = ref == null ? null : await _store.read(ref);
      if (password == null || password.isEmpty) {
        return const Err(AuthFailure('No saved ZenTao password'));
      }
      // The REST login matches the account case-insensitively, xxd does
      // not: a handle typed as `abc` for account `Abc` syncs fine but is
      // refused by chat. Sign in with the name ZenTao itself reports.
      final name = await _local.zenTaoAccountName(accountId) ?? account.handle;
      return Ok(
        XxdCredentials(
          server: server,
          account: name,
          password: password,
          pinnedFingerprint: chat?.pinnedFingerprint,
        ),
      );
    } on Exception catch (e) {
      return Err(StorageFailure('Could not read chat credentials', cause: e));
    }
  }
}

/// Default xxd address for a ZenTao base URL: same host, HTTPS port 11443.
Uri? xxdServerFor(String? zentaoBaseUrl) {
  final base = zentaoBaseUrl == null ? null : Uri.tryParse(zentaoBaseUrl);
  if (base == null || base.host.isEmpty) return null;
  return Uri(scheme: 'https', host: base.host, port: 11443);
}
